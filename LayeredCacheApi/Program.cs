using LayeredCacheApi.Cache;
using Microsoft.Extensions.Options;
using EasyCaching.Core;
using EasyCaching.Core.Configurations;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<CacheSettings>(builder.Configuration.GetSection("CacheSettings"));

builder.Services.AddMemoryCache();
builder.Services.AddScoped<RequestCache>();

builder.Services.AddEasyCaching(options =>
{
    options.UseRedis(redisOpts =>
    {
        redisOpts.DBConfig.Endpoints.Add(new ServerEndPoint("localhost", 6379));
        redisOpts.DBConfig.AllowAdmin = true;
    }, "redis");
});

builder.Services.AddScoped<RedisCacheRepository>();

builder.Services.AddScoped<IDistributedCacheRepository>(sp =>
    new TieredCacheRepository(
        sp.GetRequiredService<RedisCacheRepository>(),
        sp.GetRequiredService<RequestCache>(),
        sp.GetRequiredService<IMemoryCache>(),
        sp.GetRequiredService<IOptions<CacheSettings>>()
    ));

builder.Services.AddControllers();

var app = builder.Build();

app.MapControllers();

app.Run();
