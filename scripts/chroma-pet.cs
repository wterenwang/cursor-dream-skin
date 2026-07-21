// Edge-flood chroma → true PNG alpha. Supports magenta (#FF00FF) and green (#00FF00) screens.
// Does NOT globally wipe magenta-family pixels (safe for purple hair).
// Usage: chroma-pet.exe in.png out.png
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

class ChromaPet {
  static bool IsScreen(byte r, byte g, byte b) {
    // Exact keys
    if (r == 255 && g == 0 && b == 255) return true;
    if (r == 0 && g == 255 && b == 0) return true;
    // Magenta screen (high R+B, low G)
    if (r >= 220 && b >= 220 && g <= 60) return true;
    if (r >= 200 && b >= 200 && g <= 40) return true;
    // Green screen (high G, low R+B)
    if (g >= 220 && r <= 60 && b <= 60) return true;
    if (g >= 200 && r <= 40 && b <= 40) return true;
    // Gray checkerboard (AI artifact)
    int mx = Math.Max(r, Math.Max(g, b));
    int mn = Math.Min(r, Math.Min(g, b));
    if ((mx - mn) <= 45 && mx >= 90 && mn >= 70) return true;
    return false;
  }

  static void PaintClear(byte[] px, int o) {
    px[o] = 0; px[o + 1] = 0; px[o + 2] = 0; px[o + 3] = 0;
  }

  static bool IsClear(byte[] px, int o) { return px[o + 3] == 0; }

  static void Main(string[] args) {
    if (args.Length < 2) { Console.Error.WriteLine("usage: chroma-pet in.png out.png"); Environment.Exit(2); }
    string input = args[0], output = args[1];
    using (var src = new Bitmap(input))
    using (var bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bmp)) {
        g.Clear(Color.Transparent);
        g.DrawImage(src, 0, 0, src.Width, src.Height);
      }
      int w = bmp.Width, h = bmp.Height;
      var rect = new Rectangle(0, 0, w, h);
      var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      int stride = data.Stride;
      byte[] px = new byte[stride * h];
      Marshal.Copy(data.Scan0, px, 0, px.Length);

      bool[] visited = new bool[w * h];
      var q = new Queue<int>();
      Action<int, int> tryEnq = (x, y) => {
        if (x < 0 || y < 0 || x >= w || y >= h) return;
        int i = y * w + x;
        if (visited[i]) return;
        int o = y * stride + x * 4;
        byte b = px[o], gch = px[o + 1], r = px[o + 2], a = px[o + 3];
        if (a == 0 || IsScreen(r, gch, b)) {
          visited[i] = true;
          q.Enqueue(i);
        }
      };

      for (int x = 0; x < w; x++) { tryEnq(x, 0); tryEnq(x, h - 1); }
      for (int y = 0; y < h; y++) { tryEnq(0, y); tryEnq(w - 1, y); }

      while (q.Count > 0) {
        int i = q.Dequeue();
        int x = i % w, y = i / w;
        PaintClear(px, y * stride + x * 4);
        tryEnq(x + 1, y); tryEnq(x - 1, y); tryEnq(x, y + 1); tryEnq(x, y - 1);
      }

      // One soft pass: only clear obvious screen fringe next to already-cleared pixels
      // (do NOT clear skin / fabric mid-tones — that punched holes in legs)
      for (int pass = 0; pass < 1; pass++) {
        var marks = new List<int>();
        for (int y = 1; y < h - 1; y++) {
          for (int x = 1; x < w - 1; x++) {
            int o = y * stride + x * 4;
            if (IsClear(px, o)) continue;
            bool near = false;
            int[] dx = { 1, -1, 0, 0 };
            int[] dy = { 0, 0, 1, -1 };
            for (int k = 0; k < 4; k++) {
              if (IsClear(px, (y + dy[k]) * stride + (x + dx[k]) * 4)) { near = true; break; }
            }
            if (!near) continue;
            byte b = px[o], gch = px[o + 1], r = px[o + 2];
            if (IsScreen(r, gch, b)) marks.Add(o);
          }
        }
        foreach (int o in marks) PaintClear(px, o);
      }

      Marshal.Copy(px, 0, data.Scan0, px.Length);
      bmp.UnlockBits(data);
      string dir = System.IO.Path.GetDirectoryName(System.IO.Path.GetFullPath(output));
      if (!string.IsNullOrEmpty(dir)) System.IO.Directory.CreateDirectory(dir);
      if (System.IO.File.Exists(output)) System.IO.File.Delete(output);
      bmp.Save(output, ImageFormat.Png);
    }
    Console.WriteLine("OK " + output);
  }
}
