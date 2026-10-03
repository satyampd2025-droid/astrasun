import unittest

from astrasun import stages


class TestStageOfAnOrder(unittest.TestCase):
	"""One ladder of words for every screen. These rules need no database."""

	def stage(self, approval="Approved", **facts):
		return stages.describe(approval, **facts)

	def test_waiting_for_approval(self):
		got = self.stage("Pending Approval")
		self.assertEqual((got["stage"], got["step"], got["tone"]), ("Waiting for approval", 1, "wait"))

	def test_orders_that_are_not_on_the_ladder_keep_their_own_word(self):
		for approval, tone in (("Draft", "wait"), ("Sent Back", "warn"), ("Rejected", "stop")):
			with self.subTest(approval):
				got = self.stage(approval)
				self.assertEqual((got["stage"], got["step"], got["tone"]), (approval, 0, tone))
				self.assertEqual(got["timeline"], [])

	def test_cancelled_order(self):
		got = self.stage("Approved", cancelled=True)
		self.assertEqual((got["stage"], got["tone"], got["timeline"]), ("Cancelled", "stop", []))

	def test_approved_and_nobody_has_started(self):
		got = self.stage()
		self.assertEqual((got["stage"], got["step"], got["tone"]), ("Approved", 2, "go"))

	def test_it_follows_the_truck(self):
		for truck, stage in (("Loading", "Loading"), ("Loaded", "Loaded"), ("Dispatched", "On the way")):
			with self.subTest(truck):
				self.assertEqual(self.stage(trucks=[truck])["stage"], stage)

	def test_the_truck_furthest_behind_decides(self):
		self.assertEqual(self.stage(trucks=["Dispatched", "Loading"])["stage"], "Loading")
		self.assertEqual(self.stage(trucks=["Delivered", "Loaded"])["stage"], "Loaded")

	def test_one_truck_delivered_but_goods_still_to_send_is_not_delivered(self):
		self.assertEqual(self.stage(trucks=["Delivered"], fully_delivered=False)["stage"], "Approved")

	def delivered(self, billed, outstanding):
		return self.stage(trucks=["Delivered"], fully_delivered=True, billed=billed, outstanding=outstanding)

	def test_delivered_and_nothing_paid(self):
		got = self.delivered(10000, 10000)
		self.assertEqual((got["stage"], got["step"], got["tone"]), ("Delivered, payment pending", 6, "warn"))

	def test_delivered_and_nothing_billed_yet_is_also_payment_pending(self):
		self.assertEqual(self.delivered(0, 0)["stage"], "Delivered, payment pending")

	def test_part_paid(self):
		got = self.delivered(10000, 4000)
		self.assertEqual((got["stage"], got["step"], got["tone"]), ("Part paid", 6, "warn"))

	def test_paid(self):
		got = self.delivered(10000, 0)
		self.assertEqual((got["stage"], got["step"], got["tone"]), ("Paid", 7, "done"))

	def test_a_few_paise_left_over_still_counts_as_paid(self):
		self.assertEqual(self.delivered(10000, 0.004)["stage"], "Paid")

	def test_money_received_before_the_truck_arrives_does_not_move_the_stage(self):
		got = self.stage(trucks=["Dispatched"], billed=10000, outstanding=0)
		self.assertEqual(got["stage"], "On the way")

	def states(self, got):
		return [row["state"] for row in got["timeline"]]

	def test_timeline_has_a_row_for_every_step(self):
		got = self.stage("Pending Approval")
		self.assertEqual(
			[row["label"] for row in got["timeline"]],
			["Waiting for approval", "Approved", "Loading", "Loaded", "On the way", "Delivered", "Paid"],
		)

	def test_timeline_marks_what_is_done_where_it_is_and_what_is_left(self):
		got = self.stage(trucks=["Dispatched"])
		self.assertEqual(self.states(got), ["done", "done", "done", "done", "current", "todo", "todo"])

	def test_timeline_names_the_payment_state_on_the_delivered_row(self):
		got = self.delivered(10000, 4000)
		self.assertEqual(self.states(got), ["done"] * 5 + ["current", "todo"])
		self.assertEqual(got["timeline"][5]["label"], "Part paid")

	def test_timeline_is_all_done_once_paid(self):
		self.assertEqual(self.states(self.delivered(10000, 0)), ["done"] * 7)

	def test_the_words_on_a_truck_card_are_the_same_words(self):
		for status, stage in (
			("Waiting", "Approved"),
			("Loading", "Loading"),
			("Loaded", "Loaded"),
			("Dispatched", "On the way"),
			("Delivered", "Delivered"),
		):
			with self.subTest(status):
				self.assertEqual(stages.truck_stage(status), stage)
		self.assertEqual(stages.truck_stage("Something else"), "Something else")
