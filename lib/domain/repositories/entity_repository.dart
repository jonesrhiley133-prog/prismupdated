/// CRUD for a simple synced entity.
abstract class EntityRepository<T> {
  Stream<List<T>> watchAll();
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> create(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
}
