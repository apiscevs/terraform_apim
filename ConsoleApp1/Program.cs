using System.Text;
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
        
        HashRouter.PrintDistribution(1_00_000, 2000);
   	}
    
    public static class HashRouter
    {
        private static readonly Murmur128 Hasher = MurmurHash.Create128();

        public static int GetBucket(string key, int bucketCount)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(key);
            byte[] hash = Hasher.ComputeHash(bytes);
            ulong uhash = BitConverter.ToUInt64(hash, 0);
            return JumpHash(uhash, bucketCount);
        }

        private static int JumpHash(ulong key, int numBuckets)
        {
            long b = -1, j = 0;
            while (j < numBuckets)
            {
                b = j;
                key = key * 2862933555777941757UL + 1;
                j = (long)((b + 1) * (1L << 31) / ((double)((key >> 33) + 1)));
            }
            return (int)b;
        }

        public static void PrintDistribution(int totalKeys, int bucketCount)
        {
            var buckets = Enumerable.Range(0, bucketCount)
                .ToDictionary(i => i, _ => 0);

            for (int i = 1; i <= totalKeys; i++)
            {
                string key = $"Key-{i:D5}";
                int bucket = GetBucket(key, bucketCount);
                buckets[bucket]++;
            }

            Console.WriteLine($"Distribution for {totalKeys} keys across {bucketCount} buckets:\n");
            foreach (var kvp in buckets.OrderBy(k => k.Key))
            {
                int barLength = kvp.Value * 30 / totalKeys;
                Console.WriteLine($"Bucket {kvp.Key:D2}: {kvp.Value,4} keys  {new string('█', barLength)}");
            }

            var spread = buckets.Max(b => b.Value) - buckets.Min(b => b.Value);
            Console.WriteLine($"\nSpread (max - min): {spread} keys");
        }
    }

}

