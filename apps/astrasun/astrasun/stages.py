"""Where an order stands, in one set of words for every screen.

The sales rep, the owner, the warehouse and the driver all read the same ladder:
Waiting for approval, Approved, Loading, Loaded, On the way, Delivered, Paid.
These rules are plain Python with no database. `orders.summary` gathers the facts
about an order (its approval, its trucks, its bills) and asks `describe`.
"""

DRAFT, SENT_BACK, REJECTED, CANCELLED = "Draft", "Sent Back", "Rejected", "Cancelled"
WAITING = "Waiting for approval"
APPROVED = "Approved"
LOADING = "Loading"
LOADED = "Loaded"
ON_THE_WAY = "On the way"
DELIVERED = "Delivered"
PAYMENT_PENDING = "Delivered, payment pending"
PART_PAID = "Part paid"
PAID = "Paid"

# The rows of the timeline, in order. A stage sits on the row it belongs to.
LADDER = (WAITING, APPROVED, LOADING, LOADED, ON_THE_WAY, DELIVERED, PAID)

_STEP = {
	WAITING: 1,
	APPROVED: 2,
	LOADING: 3,
	LOADED: 4,
	ON_THE_WAY: 5,
	PAYMENT_PENDING: 6,
	PART_PAID: 6,
	PAID: 7,
}

# How the phone colours a stage: wait (grey), go (blue), warn (amber), done (green), stop (red)
_TONE = {
	DRAFT: "wait",
	WAITING: "wait",
	SENT_BACK: "warn",
	REJECTED: "stop",
	CANCELLED: "stop",
	APPROVED: "go",
	LOADING: "go",
	LOADED: "go",
	ON_THE_WAY: "go",
	PAYMENT_PENDING: "warn",
	PART_PAID: "warn",
	PAID: "done",
}

# A truck's own loading status (on its Delivery Note), and the stage it stands for
_TRUCK = {
	"Waiting": APPROVED,
	"Loading": LOADING,
	"Loaded": LOADED,
	"Dispatched": ON_THE_WAY,
	"Delivered": DELIVERED,
}
# The trucks that have not yet delivered, furthest behind first
_ON_THE_ROAD_TO_DELIVERY = ("Loading", "Loaded", "Dispatched")


def truck_stage(loading_status):
	"""The ladder's word for a truck card (loading, dispatch, driver screens)."""
	return _TRUCK.get(loading_status, loading_status)


def _stage(approval, trucks, fully_delivered, billed, outstanding, cancelled):
	if cancelled:
		return CANCELLED
	if approval == "Pending Approval":
		return WAITING
	if approval != "Approved":
		return approval or DRAFT
	active = [t for t in trucks if t in _ON_THE_ROAD_TO_DELIVERY]
	if active:
		# The truck furthest behind says where the order is
		return _TRUCK[min(active, key=_ON_THE_ROAD_TO_DELIVERY.index)]
	if not (trucks and fully_delivered):
		return APPROVED
	if billed > 0 and round(outstanding, 2) <= 0:
		return PAID
	if billed > 0 and round(billed - outstanding, 2) > 0:
		return PART_PAID
	return PAYMENT_PENDING


def _timeline(stage, step):
	if not step:
		return []
	rows = []
	for number, label in enumerate(LADDER, start=1):
		if step == len(LADDER) or number < step:
			state = "done"
		elif number == step:
			# The row says what is true now, e.g. "Part paid" on the Delivered row
			state, label = "current", stage
		else:
			state = "todo"
		rows.append({"label": label, "state": state})
	return rows


def describe(
	approval, trucks=(), fully_delivered=False, billed=0, outstanding=0, cancelled=False
):
	"""The stage of an order, its colour, its place on the ladder and the timeline rows.

	`trucks` are the loading statuses of the order's Delivery Notes; `billed` and
	`outstanding` add up its submitted invoices.
	"""
	stage = _stage(approval, trucks, fully_delivered, billed, outstanding, cancelled)
	step = _STEP.get(stage, 0)
	return {
		"stage": stage,
		"step": step,
		"tone": _TONE.get(stage, "wait"),
		"timeline": _timeline(stage, step),
	}
