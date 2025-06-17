namespace LayeredCacheApi.Cache;

public interface IDistributedCacheRepository
{
    Task<T?> GetAsync<T>(string key);
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null);
}
