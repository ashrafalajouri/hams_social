class StoreItem {
  final String id;
  final String type;
  final String title;
  final String description;
  final int price;

  const StoreItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.price,
  });
}

class StoreCatalog {
  static const items = <StoreItem>[
    StoreItem(
      id: 'frame_gold',
      type: 'frame',
      title: 'Gold Frame',
      description: 'A premium golden profile frame.',
      price: 50,
    ),
    StoreItem(
      id: 'frame_neon',
      type: 'frame',
      title: 'Neon Frame',
      description: 'Cyber neon glow frame.',
      price: 80,
    ),
    StoreItem(
      id: 'banner_sky',
      type: 'banner',
      title: 'Sky Banner',
      description: 'Soft sky gradient banner.',
      price: 60,
    ),
    StoreItem(
      id: 'banner_dark',
      type: 'banner',
      title: 'Dark Banner',
      description: 'Dark sleek banner style.',
      price: 90,
    ),
    StoreItem(
      id: 'theme_classic',
      type: 'theme',
      title: 'Classic Theme',
      description: 'Clean classic UI theme.',
      price: 40,
    ),
    StoreItem(
      id: 'theme_midnight',
      type: 'theme',
      title: 'Midnight Theme',
      description: 'Deep midnight theme.',
      price: 120,
    ),
  ];
}
