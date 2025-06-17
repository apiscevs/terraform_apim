using LayeredCacheApi.Cache;
using LayeredCacheApi.Models;
using Microsoft.AspNetCore.Mvc;

namespace LayeredCacheApi.Controllers;

[ApiController]
[Route("[controller]")]
public class WeatherForecastController : ControllerBase
{
    private readonly IDistributedCacheRepository _cache;
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    public WeatherForecastController(IDistributedCacheRepository cache)
    {
        _cache = cache;
    }

    [HttpGet("{id}")]
    public async Task<WeatherForecast?> Get(int id)
    {
        var key = $"weather:{id}";
        var cached = await _cache.GetAsync<WeatherForecast>(key);
        if (cached != null)
            return cached;

        var rng = new Random(id);
        var forecast = new WeatherForecast
        {
            Date = DateTime.Now.AddDays(id),
            TemperatureC = rng.Next(-20, 55),
            Summary = Summaries[rng.Next(Summaries.Length)]
        };

        await _cache.SetAsync(key, forecast, TimeSpan.FromMinutes(1));
        return forecast;
    }
}
