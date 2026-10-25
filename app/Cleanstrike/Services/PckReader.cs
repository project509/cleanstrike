using System.Text;

namespace Cleanstrike.Services;

/// <summary>
/// Reads the Godot engine version and the game's project settings
/// (config/version, custom user dir) straight from the .pck, without
/// loading the multi-GB file.
/// </summary>
public static class PckReader
{
    public sealed record Info(string GodotVersion, Dictionary<string, string> Settings);

    public static Info? Read(string pckPath)
    {
        try
        {
            using var fs = new FileStream(pckPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var br = new BinaryReader(fs);
            if (Encoding.ASCII.GetString(br.ReadBytes(4)) != "GDPC") return null;
            uint format = br.ReadUInt32();
            uint major = br.ReadUInt32(), minor = br.ReadUInt32(), patch = br.ReadUInt32();
            var godot = $"{major}.{minor}.{patch}";
            uint flags = 0;
            long fileBase = 0, dirOffset = -1;
            if (format >= 2)
            {
                flags = br.ReadUInt32();
                fileBase = br.ReadInt64();
            }
            if (format >= 3) dirOffset = br.ReadInt64();
            br.ReadBytes(16 * 4); // reserved
            if (dirOffset > 0) fs.Position = dirOffset;
            var settings = new Dictionary<string, string>();
            if ((flags & 1) != 0) return new Info(godot, settings); // encrypted directory

            uint count = br.ReadUInt32();
            for (uint n = 0; n < count; n++)
            {
                int len = br.ReadInt32();
                var path = Encoding.UTF8.GetString(br.ReadBytes(len)).TrimEnd('\0');
                long offset = br.ReadInt64();
                long size = br.ReadInt64();
                br.ReadBytes(16); // md5
                if (format >= 2) br.ReadUInt32(); // per-file flags
                if (path is "project.binary" or "res://project.binary")
                {
                    if ((flags & 2) != 0 || format >= 3) offset += fileBase;
                    long back = fs.Position;
                    fs.Position = offset;
                    ReadProjectBinary(br.ReadBytes((int)Math.Min(size, 4_000_000)), settings);
                    fs.Position = back;
                    break;
                }
            }
            return new Info(godot, settings);
        }
        catch (Exception e)
        {
            Log.Write("PCK read failed: " + e.Message);
            return null;
        }
    }

    // project.binary: "ECFG", u32 count, then (u32 keylen, key, u32 datalen, variant).
    // Only String variants are decoded; that's all we need.
    private static void ReadProjectBinary(byte[] data, Dictionary<string, string> into)
    {
        if (data.Length < 8 || Encoding.ASCII.GetString(data, 0, 4) != "ECFG") return;
        int p = 4;
        int count = BitConverter.ToInt32(data, p); p += 4;
        for (int i = 0; i < count && p + 8 <= data.Length; i++)
        {
            int klen = BitConverter.ToInt32(data, p); p += 4;
            if (klen < 0 || p + klen > data.Length) return;
            var key = Encoding.UTF8.GetString(data, p, klen).TrimEnd('\0'); p += klen;
            int dlen = BitConverter.ToInt32(data, p); p += 4;
            if (dlen < 0 || p + dlen > data.Length) return;
            if (dlen >= 8 && (BitConverter.ToInt32(data, p) & 0xFFFF) == 4) // Variant::STRING
            {
                int slen = BitConverter.ToInt32(data, p + 4);
                if (slen >= 0 && slen <= dlen - 8)
                    into[key] = Encoding.UTF8.GetString(data, p + 8, slen);
            }
            p += dlen;
        }
    }
}
