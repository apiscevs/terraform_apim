using Murmur;

namespace ConsoleApp1;

class Program
{
    static void Main(string[] args)
    {
        const int totalKeys = 1000;
        const int bucketCount = 10;

        var buckets = new Dictionary<int, int>();
        for (int i = 0; i < bucketCount; i++)
            buckets[i] = 0;

        var hasher = MurmurHash.Create32();

        for (int i = 1; i <= totalKeys; i++)
        {
            string key = $"Key-{i:D4}";
            byte[] bytes = System.Text.Encoding.UTF8.GetBytes(key);
            int hash = BitConverter.ToInt32(hasher.ComputeHash(bytes), 0);
            int bucket = Math.Abs(hash % bucketCount);
            buckets[bucket]++;
        }

        Console.WriteLine("Bucket distribution:");
        foreach (var kvp in buckets.OrderBy(k => k.Key))
        {
            Console.WriteLine($"Bucket {kvp.Key}: {kvp.Value} keys");
        }
    }
}