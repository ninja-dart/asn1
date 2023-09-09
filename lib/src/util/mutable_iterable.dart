class MutableIterable implements Iterable<int> {
  Iterable<int> _base;

  set mutate(Iterable<int> value) {
    _base = value;
  }

  MutableIterable(this._base);

  @override
  bool any(bool Function(int element) test) => _base.any(test);

  @override
  Iterable<T> cast<T>() => _base.cast<T>();

  @override
  bool contains(Object? element) => _base.contains(element);

  @override
  int elementAt(int index) => _base.elementAt(index);

  @override
  bool every(bool Function(int element) test) => _base.every(test);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(int element) f) => _base.expand(f);

  @override
  int get first => _base.first;

  @override
  int firstWhere(bool Function(int element) test, {int Function()? orElse}) =>
      _base.firstWhere(test, orElse: orElse);

  @override
  T fold<T>(T initialValue, T Function(T previousValue, int element) combine) =>
      _base.fold(initialValue, combine);

  @override
  Iterable<int> followedBy(Iterable<int> other) => _base.followedBy(other);

  @override
  void forEach(void Function(int element) f) => _base.forEach(f);

  @override
  bool get isEmpty => _base.isEmpty;

  @override
  bool get isNotEmpty => _base.isNotEmpty;

  @override
  Iterator<int> get iterator => _base.iterator;

  @override
  String join([String separator = '']) => _base.join(separator);

  @override
  int get last => _base.last;

  @override
  int lastWhere(bool Function(int element) test, {int Function()? orElse}) =>
      _base.lastWhere(test, orElse: orElse);

  int get length => _base.length;

  @override
  Iterable<T> map<T>(T Function(int element) f) => _base.map(f);

  @override
  int reduce(int Function(int value, int element) combine) =>
      _base.reduce(combine);

  @override
  int get single => _base.single;

  @override
  int singleWhere(bool Function(int element) test, {int Function()? orElse}) {
    return _base.singleWhere(test, orElse: orElse);
  }

  @override
  Iterable<int> skip(int n) => _base.skip(n);

  @override
  Iterable<int> skipWhile(bool Function(int value) test) =>
      _base.skipWhile(test);

  @override
  Iterable<int> take(int n) => _base.take(n);

  @override
  Iterable<int> takeWhile(bool Function(int value) test) =>
      _base.takeWhile(test);

  @override
  List<int> toList({bool growable = true}) => _base.toList(growable: growable);

  @override
  Set<int> toSet() => _base.toSet();

  @override
  Iterable<int> where(bool Function(int element) test) => _base.where(test);

  @override
  Iterable<T> whereType<T>() => _base.whereType<T>();

  @override
  String toString() => _base.toString();
}
