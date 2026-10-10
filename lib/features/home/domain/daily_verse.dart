/// Curated verses from the World English Bible (public domain), rotated by
/// day of year. This is app content, not placeholder data.
class DailyVerse {
  const DailyVerse(this.text, this.reference);
  final String text;
  final String reference;

  static const translation = 'WEB';

  static const _verses = [
    DailyVerse(
      'Your word is a lamp to my feet, and a light for my path.',
      'Psalm 119:105',
    ),
    DailyVerse('The Lord is my shepherd; I shall lack nothing.', 'Psalm 23:1'),
    DailyVerse(
      'Trust in the Lord with all your heart, and don’t lean on your own understanding.',
      'Proverbs 3:5',
    ),
    DailyVerse(
      'Come to me, all you who labor and are heavily burdened, and I will give you rest.',
      'Matthew 11:28',
    ),
    DailyVerse(
      'I am the vine. You are the branches. He who remains in me and I in him bears much fruit.',
      'John 15:5',
    ),
    DailyVerse(
      'We know that all things work together for good for those who love God.',
      'Romans 8:28',
    ),
    DailyVerse('Be still, and know that I am God.', 'Psalm 46:10'),
    DailyVerse(
      'The steadfast love of the Lord never ceases. His mercies never come to an end.',
      'Lamentations 3:22',
    ),
    DailyVerse(
      'In the beginning was the Word, and the Word was with God, and the Word was God.',
      'John 1:1',
    ),
    DailyVerse(
      'Faith is assurance of things hoped for, proof of things not seen.',
      'Hebrews 11:1',
    ),
    DailyVerse(
      'I can do all things through Christ, who strengthens me.',
      'Philippians 4:13',
    ),
    DailyVerse(
      'Love is patient and is kind. Love doesn’t envy.',
      '1 Corinthians 13:4',
    ),
    DailyVerse(
      'You are the light of the world. A city located on a hill can’t be hidden.',
      'Matthew 5:14',
    ),
    DailyVerse(
      'Delight yourself also in the Lord, and he will give you the desires of your heart.',
      'Psalm 37:4',
    ),
    DailyVerse(
      'Those who wait for the Lord will renew their strength.',
      'Isaiah 40:31',
    ),
    DailyVerse(
      'Rejoice in the Lord always! Again I will say, “Rejoice!”',
      'Philippians 4:4',
    ),
    DailyVerse(
      'God is our refuge and strength, a very present help in trouble.',
      'Psalm 46:1',
    ),
    DailyVerse('Draw near to God, and he will draw near to you.', 'James 4:8'),
    DailyVerse(
      'This is the day that the Lord has made. We will rejoice and be glad in it!',
      'Psalm 118:24',
    ),
    DailyVerse('Peace I leave with you. My peace I give to you.', 'John 14:27'),
    DailyVerse(
      'Create in me a clean heart, O God. Renew a right spirit within me.',
      'Psalm 51:10',
    ),
  ];

  static DailyVerse forDate(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return _verses[dayOfYear % _verses.length];
  }
}
