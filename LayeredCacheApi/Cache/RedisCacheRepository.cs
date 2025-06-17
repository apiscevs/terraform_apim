using EasyCaching.Core;

namespace LayeredCacheApi.Cache;

public class RedisCacheRepository : IDistributedCacheRepository
{
    private readonly IEasyCachingProvider _provider;

    public RedisCacheRepository(IEasyCachingProviderFactory factory)
    {
        _provider = factory.GetCachingProvider("redis");
    }

    public async Task<T?> GetAsync<T>(string key)
    {
        var result = await _provider.GetAsync<T>(key);
        return result.HasValue ? result.Value : default;
    }

    public Task SetAsync<T>(string key, T value, TimeSpan? expiry = null)
        => _provider.SetAsync(key, value, expiry);
}
