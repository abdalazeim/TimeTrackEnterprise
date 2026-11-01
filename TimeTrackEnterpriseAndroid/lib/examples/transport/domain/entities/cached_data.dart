/// نتيجة قراءة مع بيان هل جاءت من الذاكرة المحلية.
class CachedData<T> {
  const CachedData({
    required this.value,
    this.fromCache = false,
  });

  final T value;
  final bool fromCache;
}
