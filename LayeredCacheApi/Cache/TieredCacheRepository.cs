using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace LayeredCacheApi.Cache;

public class TieredCacheRepository : IDistributedCacheRepository
{
    private readonly IDistributedCacheRepository _redis;
    private readonly RequestCache _requestCache;
    private readonly IMemoryCache _staticCache;
    private readonly HashSet<string> _staticPrefixes;

    public TieredCacheRepository(
        IDistributedCacheRepository redis,
        RequestCache requestCache,
        IMemoryCache staticCache,
        IOptions<CacheSettings> config)
    {
        _redis = redis;
        _requestCache = requestCache;
        _staticCache = staticCache;
        _staticPrefixes = new HashSet<string>(config.Value.StaticKeyPrefixes ?? new());
    }

    private bool IsStatic(string key) => _staticPrefixes.Any(p => key.StartsWith(p, StringComparison.Ordinal));

    public async Task<T?> GetAsync<T>(string key)
    {
        if (_requestCache.TryGet<T>(key, out var val))
            return val;

        if (IsStatic(key) && _staticCache.TryGetValue<T>(key, out var staticVal))
        {
            _requestCache.Set(key, staticVal);
            return staticVal;
        }

        var remote = await _redis.GetAsync<T>(key);
        if (remote is not null)
        {
            _requestCache.Set(key, remote);
            if (IsStatic(key))
                _staticCache.Set(key, remote, TimeSpan.FromMinutes(10));
        }
        return remote;
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiry = null)
    {
        _requestCache.Set(key, value);
        if (IsStatic(key))
            _staticCache.Set(key, value, TimeSpan.FromMinutes(10));
        await _redis.SetAsync(key, value, expiry);
    }
}
