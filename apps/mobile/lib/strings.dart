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
