import '../../models/communication_item.dart';

/// The starter AAC vocabulary for the Help Me Talk board, grouped by category.
/// The AI layer grows each item's phrasing over time via `expandedPhrase`.
const List<CommunicationItem> kCommunicationItems = <CommunicationItem>[
  // Food
  CommunicationItem(label: 'Apple', emoji: '🍎', category: 'Food', phrase: 'I want an apple'),
  CommunicationItem(label: 'Banana', emoji: '🍌', category: 'Food', phrase: 'I want a banana'),
  CommunicationItem(label: 'Snack', emoji: '🍪', category: 'Food', phrase: 'I want a snack'),
  CommunicationItem(label: 'Pizza', emoji: '🍕', category: 'Food', phrase: 'I want pizza'),
  CommunicationItem(label: 'Rice', emoji: '🍚', category: 'Food', phrase: 'I want rice'),
  CommunicationItem(label: 'More', emoji: '➕', category: 'Food', phrase: 'I want more'),
  // Drink
  CommunicationItem(label: 'Water', emoji: '💧', category: 'Drink', phrase: 'I want water'),
  CommunicationItem(label: 'Milk', emoji: '🥛', category: 'Drink', phrase: 'I want milk'),
  CommunicationItem(label: 'Juice', emoji: '🧃', category: 'Drink', phrase: 'I want juice'),
  // Emotions
  CommunicationItem(label: 'Happy', emoji: '😊', category: 'Emotions', phrase: 'I feel happy'),
  CommunicationItem(label: 'Sad', emoji: '😢', category: 'Emotions', phrase: 'I feel sad'),
  CommunicationItem(label: 'Angry', emoji: '😡', category: 'Emotions', phrase: 'I feel angry'),
  CommunicationItem(label: 'Scared', emoji: '😨', category: 'Emotions', phrase: 'I feel scared'),
  CommunicationItem(label: 'Tired', emoji: '😴', category: 'Emotions', phrase: 'I feel tired'),
  CommunicationItem(label: 'Love', emoji: '❤️', category: 'Emotions', phrase: 'I love you'),
  // Activities
  CommunicationItem(label: 'Car', emoji: '🚗', category: 'Activities', phrase: 'I want my car',
      expandedPhrase: 'I would like to play with my car'),
  CommunicationItem(label: 'Play', emoji: '🧸', category: 'Activities', phrase: 'I want to play'),
  CommunicationItem(label: 'Music', emoji: '🎵', category: 'Activities', phrase: 'I want music'),
  CommunicationItem(label: 'Tablet', emoji: '📱', category: 'Activities', phrase: 'I want the tablet'),
  CommunicationItem(label: 'Read', emoji: '📖', category: 'Activities', phrase: 'I want a story'),
  // Places
  CommunicationItem(label: 'Outside', emoji: '🌳', category: 'Places', phrase: 'I want to go outside'),
  CommunicationItem(label: 'Park', emoji: '🛝', category: 'Places', phrase: 'I want to go to the park'),
  CommunicationItem(label: 'Home', emoji: '🏠', category: 'Places', phrase: 'I want to go home'),
  CommunicationItem(label: 'Bed', emoji: '🛏️', category: 'Places', phrase: 'I want to go to bed'),
  // Needs
  CommunicationItem(label: 'Toilet', emoji: '🚽', category: 'Needs', phrase: 'I need the toilet'),
  CommunicationItem(label: 'Help', emoji: '🙋', category: 'Needs', phrase: 'I need help'),
  CommunicationItem(label: 'Break', emoji: '⏸️', category: 'Needs', phrase: 'I need a break'),
  CommunicationItem(label: 'Hug', emoji: '🤗', category: 'Needs', phrase: 'I need a hug'),
  CommunicationItem(label: 'Quiet', emoji: '🤫', category: 'Needs', phrase: 'I need it quiet'),
  CommunicationItem(label: 'Yes', emoji: '👍', category: 'Needs', phrase: 'Yes'),
  CommunicationItem(label: 'No', emoji: '👎', category: 'Needs', phrase: 'No'),
  // Family
  CommunicationItem(label: 'Mum', emoji: '👩', category: 'Family', phrase: 'I want Mum'),
  CommunicationItem(label: 'Dad', emoji: '👨', category: 'Family', phrase: 'I want Dad'),
  CommunicationItem(label: 'Grandma', emoji: '👵', category: 'Family', phrase: 'I want Grandma'),
  CommunicationItem(label: 'Grandpa', emoji: '👴', category: 'Family', phrase: 'I want Grandpa'),
  // Favorites
  CommunicationItem(label: 'Dog', emoji: '🐶', category: 'Favorites', phrase: 'I want the dog'),
  CommunicationItem(label: 'Cat', emoji: '🐱', category: 'Favorites', phrase: 'I want the cat'),
  CommunicationItem(label: 'Ball', emoji: '⚽', category: 'Favorites', phrase: 'I want the ball'),
  CommunicationItem(label: 'Blocks', emoji: '🧱', category: 'Favorites', phrase: 'I want my blocks'),
];

List<CommunicationItem> itemsForCategory(String category) =>
    kCommunicationItems.where((i) => i.category == category).toList();
