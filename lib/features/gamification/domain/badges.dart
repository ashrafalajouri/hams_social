class Badge {
  final String id;
  final String title;
  final String description;

  const Badge({
    required this.id,
    required this.title,
    required this.description,
  });
}

class Badges {
  static const risingVoice = Badge(
    id: 'rising_voice',
    title: 'Rising Voice',
    description: 'Reached Level 2',
  );

  static const popular = Badge(
    id: 'popular',
    title: 'Popular',
    description: 'Received 20 likes',
  );

  static const openSpeaker = Badge(
    id: 'open_speaker',
    title: 'Open Speaker',
    description: 'Posted 10 public replies',
  );

  static const trustedProfile = Badge(
    id: 'trusted_profile',
    title: 'Trusted Profile',
    description: 'Received 50 messages',
  );

  static const all = [
    risingVoice,
    popular,
    openSpeaker,
    trustedProfile,
  ];

  static const badgeMap = {
    'rising_voice': risingVoice,
    'popular': popular,
    'open_speaker': openSpeaker,
    'trusted_profile': trustedProfile,
  };
}
