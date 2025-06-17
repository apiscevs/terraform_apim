# LayeredCacheApi

This sample ASP.NET Core Web API demonstrates a layered caching approach using
a per-request cache, a process-wide in-memory cache for static keys, and Redis
via the **EasyCaching** library as the backing store.

## Running

The API targets .NET 6 and uses EasyCaching.Redis. Ensure Redis is running
locally (adjust the connection string in `Program.cs` if needed) and that the
NET 6 SDK is installed.

```
dotnet restore
 dotnet run --project LayeredCacheApi.csproj
```

The weather forecast endpoint illustrates usage:
`GET /WeatherForecast/1`

Static key prefixes for the longer-lived cache tier can be configured in
`appsettings.json` under `CacheSettings:StaticKeyPrefixes`.
