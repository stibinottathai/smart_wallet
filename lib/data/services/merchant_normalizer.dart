class MerchantNormalizer {
  static String normalize(String rawMerchant) {
    if (rawMerchant.trim().isEmpty) return 'Unknown';
    
    final cleaned = rawMerchant.trim().toLowerCase();
    
    if (cleaned.contains('amazon')) return 'Amazon';
    if (cleaned.contains('swiggy')) return 'Swiggy';
    if (cleaned.contains('uber')) return 'Uber';
    if (cleaned.contains('zomato')) return 'Zomato';
    if (cleaned.contains('phonepe')) return 'PhonePe';
    if (cleaned.contains('gpay') || cleaned.contains('google pay') || cleaned.contains('googlepay')) return 'Google Pay';
    if (cleaned.contains('netflix')) return 'Netflix';
    if (cleaned.contains('spotify')) return 'Spotify';
    if (cleaned.contains('ola cab') || cleaned.contains('ola ride') || cleaned.contains('olacabs')) return 'Ola';
    if (cleaned.contains('flipkart')) return 'Flipkart';
    if (cleaned.contains('jiomart') || cleaned.contains('reliance retail')) return 'JioMart';
    if (cleaned.contains('blinkit')) return 'Blinkit';
    if (cleaned.contains('indian oil') || cleaned.contains('indianoil') || cleaned.contains('iocl')) return 'Indian Oil';
    if (cleaned.contains('hpcl') || cleaned.contains('hindustan petroleum')) return 'HPCL';
    if (cleaned.contains('bpcl') || cleaned.contains('bharat petroleum')) return 'BPCL';
    if (cleaned.contains('salary') || cleaned.contains('payslip')) return 'Salary';
    
    // Capitalize words nicely
    final words = rawMerchant.split(RegExp(r'\s+'));
    return words.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ').trim();
  }
}
