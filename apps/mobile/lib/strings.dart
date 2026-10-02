import 'package:flutter/widgets.dart';

/// All app text in English and Hindi. Keys are English so a missing Hindi
/// string still shows something readable.
const Map<String, Map<String, String>> _strings = {
  'hi': {
    'Atulyaa Mill': 'अतुल्य मिल',
    'Server address': 'सर्वर पता',
    'User ID': 'यूज़र आईडी',
    'Password': 'पासवर्ड',
    'Log in': 'लॉग इन करें',
    'Log out': 'लॉग आउट',
    'Wrong user ID or password': 'यूज़र आईडी या पासवर्ड गलत है',
    'Cannot reach the server. Check the internet.':
        'सर्वर से संपर्क नहीं हो पा रहा। इंटरनेट देखें।',
    'Namaste, {0}': 'नमस्ते, {0}',
    'What to do now': 'अभी क्या करना है',
    'No work assigned to your role yet. Ask the manager.':
        'आपके काम के लिए अभी कुछ तय नहीं है। मैनेजर से पूछें।',
    'Coming soon': 'जल्द आ रहा है',
    'This screen is being built.': 'यह स्क्रीन बन रही है।',
    'Back': 'वापस',
    'Speak': 'बोलें',
    'Listening...': 'सुन रहे हैं...',
    'Voice input is not available on this phone':
        'इस फ़ोन पर बोलकर लिखना उपलब्ध नहीं है',
    'Try voice input': 'बोलकर लिखें',
    'Remarks': 'टिप्पणी',
    'Try demo': 'डेमो देखें',
    'The mill server is not set up yet. Try the demo.':
        'मिल का सर्वर अभी तैयार नहीं है। डेमो देखें।',
    'Who are you?': 'आप कौन हैं?',
    'Demo: sample data, nothing is saved':
        'डेमो: नमूना डेटा, कुछ भी सेव नहीं होता',
    'Owner': 'मालिक',
    'Manager': 'मैनेजर',
    'Sales': 'सेल्स',
    'Purchase': 'खरीद',
    'Gate / weighbridge': 'गेट / कांटा',
    'Lab': 'लैब',
    'Mill operator': 'मिल ऑपरेटर',
    'Packing': 'पैकिंग',
    'Loading': 'लोडिंग',
    'Dispatch': 'डिस्पैच',
    'Driver': 'ड्राइवर',
    'Accounts': 'अकाउंट्स',
    'Auditor': 'ऑडिटर',
    'Choose customer': 'ग्राहक चुनें',
    'Add bags': 'बोरी जोड़ें',
    'Total': 'कुल',
    'Send for approval': 'मंज़ूरी के लिए भेजें',
    'Sent for approval': 'मंज़ूरी के लिए भेज दिया',
    'Could not save. Try again.': 'सेव नहीं हुआ। दोबारा कोशिश करें।',
    'Approve': 'मंज़ूर करें',
    'Reject': 'मना करें',
    'Send back': 'वापस भेजें',
    'Reason': 'कारण',
    'Done': 'ठीक है',
    'No orders waiting for you': 'आपके लिए कोई ऑर्डर बाकी नहीं',
    'No orders yet': 'अभी कोई ऑर्डर नहीं',
    'Over credit limit': 'उधार सीमा से ऊपर',
    'Stock is short': 'स्टॉक कम है',
    'Dues {0} + this order = {1} of limit {2}':
        'बकाया {0} + यह ऑर्डर = {1}, सीमा {2}',
    'Draft': 'ड्राफ्ट',
    'Pending Approval': 'मंज़ूरी बाकी',
    'Approved': 'मंज़ूर',
    'Rejected': 'मना किया',
    'Sent Back': 'वापस भेजा',
    // Loading
    'bags': 'बोरी',
    'Waiting': 'इंतज़ार में',
    'Loaded': 'लोड हो गया',
    'Start loading': 'लोडिंग शुरू करें',
    'Mark loaded': 'लोड पूरा',
    'Vehicle number': 'गाड़ी नंबर',
    'Enter the vehicle number': 'गाड़ी नंबर लिखें',
    'Nothing to load': 'लोड करने को कुछ नहीं',
    'Bags loaded': 'लोड की गई बोरी',
    'Vehicle {0}': 'गाड़ी {0}',
    // Tasks
    'Approve orders': 'ऑर्डर मंज़ूर करें',
    'Today at the mill': 'आज मिल में',
    'Alerts': 'अलर्ट',
    'Plan production': 'उत्पादन योजना',
    'Trucks at the mill': 'मिल में ट्रक',
    'Stock': 'स्टॉक',
    'New order': 'नया ऑर्डर',
    'My orders': 'मेरे ऑर्डर',
    'Customer dues': 'ग्राहक बकाया',
    'Wheat purchase': 'गेहूं खरीद',
    'Supplier rates': 'सप्लायर रेट',
    'Truck entry': 'ट्रक एंट्री',
    'Weighbridge': 'कांटा',
    'Check wheat lot': 'गेहूं लॉट जांच',
    'Check flour': 'आटा जांच',
    'Start milling batch': 'पिसाई शुरू करें',
    'Report downtime': 'मशीन बंद दर्ज करें',
    'Pack bags': 'बोरी पैक करें',
    'Loading queue': 'लोडिंग सूची',
    'Assign trucks': 'ट्रक तय करें',
    'My deliveries': 'मेरी डिलीवरी',
    'Collect payment': 'भुगतान लें',
    'Bills and payments': 'बिल और भुगतान',
    'Change log': 'बदलाव लॉग',
  },
};

class S {
  S(this.languageCode);
  final String languageCode;

  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode);

  String t(String key, [List<Object> args = const []]) {
    var text = _strings[languageCode]?[key] ?? key;
    for (var i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', '${args[i]}');
    }
    return text;
  }
}
