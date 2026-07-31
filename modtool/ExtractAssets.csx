using System;
using System.IO;
using System.Text;
using System.Threading;
using UndertaleModLib.Util;
using System.Threading.Tasks;
using System.Collections.Concurrent;

EnsureDataLoaded();

// Hardcoded output root (non-interactive). Edit this if needed.
string outRoot      = "assets-extracted";
string texFolder    = Path.Combine(outRoot, "Textures");
string spriteFolder = Path.Combine(outRoot, "Sprites");
string soundFolder  = Path.Combine(outRoot, "Sounds");

Directory.CreateDirectory(texFolder);
Directory.CreateDirectory(spriteFolder);
Directory.CreateDirectory(soundFolder);

// --- Export embedded texture pages (as 0.png, 1.png, ...) ---
SetProgressBar(null, "Embedded Textures", 0, Data.EmbeddedTextures.Count);
StartProgressBarUpdater();

await Task.Run(() =>
{
    for (int i = 0; i < Data.EmbeddedTextures.Count; i++)
    {
        try
        {
            using FileStream fs = new(Path.Combine(texFolder, $"{i}.png"), FileMode.Create);
            Data.EmbeddedTextures[i].TextureData.Image.SavePng(fs);
        }
        catch (Exception ex)
        {
            ScriptMessage($"Failed to export texture {i}: {ex.Message}");
        }
        IncrementProgress();
    }
});

await StopProgressBarUpdater();
HideProgressBar();

// --- Export all sprites (raster, no padding, grouped into subdirectories) ---
bool paddedSprites = false;
bool useSubDirs = true;

ConcurrentDictionary<string, ConcurrentBag<TextureToExport>> texturesToExport = new();

SetProgressBar(null, "Generating Sprite Cache", 0, Data.Sprites.Count);
StartProgressBarUpdater();

await Task.Run(() => Parallel.ForEach(Data.Sprites, spr =>
{
    FetchTexturesFromSprite(spr);
}));

await StopProgressBarUpdater();
HideProgressBar();

SetProgressBar(null, "Exporting Sprites", 0, texturesToExport.Count);
StartProgressBarUpdater();

await Task.Run(() => ExportTextures());

await StopProgressBarUpdater();
HideProgressBar();

void FetchTexturesFromSprite(UndertaleSprite sprite)
{
    if (sprite is not { SSpriteType: UndertaleSprite.SpriteType.Normal, Textures.Count: > 0 })
    {
        IncrementProgressParallel();
        return;
    }

    string outputFolder = spriteFolder;
    if (useSubDirs)
    {
        outputFolder = Path.Combine(outputFolder, sprite.Name.Content);
        Directory.CreateDirectory(outputFolder);
    }

    for (int i = 0; i < sprite.Textures.Count; i++)
    {
        if (sprite.Textures[i]?.Texture is not null)
        {
            UndertaleTexturePageItem pageItem = sprite.Textures[i].Texture;
            var bag = texturesToExport.GetOrAdd(pageItem.TexturePage.Name.Content, _ => new ConcurrentBag<TextureToExport>());
            bag.Add(new TextureToExport(pageItem, Path.Combine(outputFolder, $"{sprite.Name.Content}_{i}.png")));
        }
    }
    IncrementProgressParallel();
}

void ExportTextures()
{
    int totalCores = Environment.ProcessorCount;
    int outerLimit = Math.Max(1, totalCores / 4);
    Parallel.ForEach(texturesToExport, new ParallelOptions { MaxDegreeOfParallelism = outerLimit }, kvp =>
    {
        using (TextureWorker localWorker = new TextureWorker())
        {
            foreach (TextureToExport tte in kvp.Value)
            {
                localWorker.ExportAsPNG(tte.PageItem, tte.FileExportLocation, null, paddedSprites);
            }
        }
        IncrementProgressParallel();
    });
}

public class TextureToExport
{
    public UndertaleTexturePageItem PageItem { get; set; }
    public UndertaleEmbeddedTexture Page => PageItem.TexturePage;
    public string FileExportLocation { get; set; }
    public TextureToExport(UndertaleTexturePageItem pageItem, string fileExportLocation)
        => (PageItem, FileExportLocation) = (pageItem, fileExportLocation);
}

// --- Export all embedded sounds as WAV/OGG ---
byte[] EMPTY_WAV_FILE_BYTES = System.Convert.FromBase64String("UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAAB9AAAEABAAZGF0YQAAAAA=");
string DEFAULT_AUDIOGROUP_NAME = "audiogroup_default";
bool copyExternalAudio = false;
bool groupedExport = false;

Dictionary<string, IList<UndertaleEmbeddedAudio>> loadedAudioGroups = null;
IList<UndertaleEmbeddedAudio> GetAudioGroupData(UndertaleSound sound)
{
    loadedAudioGroups ??= new();
    string audioGroupName = sound.AudioGroup is not null ? sound.AudioGroup.Name.Content : DEFAULT_AUDIOGROUP_NAME;
    if (loadedAudioGroups.ContainsKey(audioGroupName))
        return loadedAudioGroups[audioGroupName];

    string relativeAudioGroupPath;
    if (sound.AudioGroup is UndertaleAudioGroup { Path.Content: string customRelativePath })
    {
        relativeAudioGroupPath = customRelativePath;
    }
    else
    {
        relativeAudioGroupPath = $"audiogroup{sound.GroupID}.dat";
    }
    string groupFilePath = Path.Combine(Path.GetDirectoryName(FilePath), relativeAudioGroupPath);
    if (!File.Exists(groupFilePath))
        return null;

    try
    {
        UndertaleData data = null;
        using (var stream = new FileStream(groupFilePath, FileMode.Open, FileAccess.Read))
        {
            data = UndertaleIO.Read(stream, (warning, _) => ScriptWarning($"Audio group load warning ({audioGroupName}):\n{warning}"));
        }
        loadedAudioGroups[audioGroupName] = data.EmbeddedAudio;
        return data.EmbeddedAudio;
    }
    catch (Exception e)
    {
        ScriptMessage($"Audio group load error ({audioGroupName}):\n{e.Message}");
        return null;
    }
}

byte[] GetSoundData(UndertaleSound sound)
{
    if (sound.AudioFile is not null)
        return sound.AudioFile.Data;
    if (sound.GroupID > Data.GetBuiltinSoundGroupID())
    {
        IList<UndertaleEmbeddedAudio> audioGroup = GetAudioGroupData(sound);
        if (audioGroup is not null)
            return audioGroup[sound.AudioID].Data;
    }
    return EMPTY_WAV_FILE_BYTES;
}

int soundMax = Data.Sounds.Count;
SetProgressBar(null, "Sounds", 0, soundMax);
StartProgressBarUpdater();

await Task.Run(() =>
{
    foreach (UndertaleSound sound in Data.Sounds)
    {
        if (sound is not null)
            DumpSound(sound);
        else if (GetProgress() < soundMax)
            IncrementProgress();
    }
});

await StopProgressBarUpdater();
HideProgressBar();

void DumpSound(UndertaleSound sound)
{
    string soundName = sound.Name.Content;
    string soundFilePath = groupedExport
        ? Path.Combine(soundFolder, sound.AudioGroup.Name.Content, soundName)
        : Path.Combine(soundFolder, soundName);
    if (groupedExport)
        Directory.CreateDirectory(Path.Combine(soundFolder, sound.AudioGroup.Name.Content));

    bool flagCompressed = sound.Flags.HasFlag(UndertaleSound.AudioEntryFlags.IsCompressed);
    bool flagEmbedded   = sound.Flags.HasFlag(UndertaleSound.AudioEntryFlags.IsEmbedded);
    string audioExt = ".ogg";
    bool isEmbedded = true;
    if (flagEmbedded && !flagCompressed)        audioExt = ".wav";
    else if (flagCompressed && !flagEmbedded)   audioExt = ".ogg";
    else if (flagCompressed && flagEmbedded)    audioExt = ".ogg";
    else if (!flagCompressed && !flagEmbedded)
    {
        isEmbedded = false;
        audioExt = ".ogg";
        if (copyExternalAudio)
        {
            string externalFilename = sound.File.Content;
            if (!externalFilename.Contains('.')) externalFilename += ".ogg";
            string sourcePath = Path.Combine(Path.GetDirectoryName(FilePath), externalFilename);
            string destDir = Path.Combine(soundFolder, "external");
            Directory.CreateDirectory(destDir);
            string destPath = groupedExport
                ? Path.Combine(soundFolder, sound.AudioGroup.Name.Content, "external", soundName + audioExt)
                : Path.Combine(destDir, soundName + audioExt);
            try { File.Copy(sourcePath, destPath, true); } catch { }
        }
    }
    if (isEmbedded)
    {
        try { File.WriteAllBytes(soundFilePath + audioExt, GetSoundData(sound)); }
        catch (Exception e) { ScriptMessage($"Failed sound {soundName}: {e.Message}"); }
    }
    if (GetProgress() < soundMax) IncrementProgress();
}

ScriptMessage("Extraction complete!");
