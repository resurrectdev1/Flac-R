package com.resurrect.flac_r

import android.util.Log
import com.mpatric.mp3agic.Mp3File
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.tag.FieldKey
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.util.logging.Level
import java.util.logging.Logger

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.resurrect.flac_r/extra_tags"
        private const val TAG     = "ExtraTagsChannel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Logger.getLogger("org.jaudiotagger").level = Level.OFF

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        .setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("MISSING_ARG", "path is required", null)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "readExtraTags"  -> result.success(readExtraTags(path))
                    "writeExtraTags" -> {
                        val composer = call.argument<String>("composer")
                        val comment  = call.argument<String>("comment")
                        writeExtraTags(path, composer, comment)
                        result.success(null)
                    }
                    "writeAllTags" -> {
                        writeAllTagsViaJaudiotagger(path, call)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in ${call.method}: ${e.message}", e)
                result.error("TAG_ERROR", e.message, null)
            }
        }
    }

    private fun readExtraTags(path: String): Map<String, String?> {
        val lower = path.lowercase()
        return when {
            lower.endsWith(".mp3")  -> readMp3ExtraTags(path)
            lower.endsWith(".flac") -> readFlacExtraTags(path)
            lower.endsWith(".m4a") || lower.endsWith(".mp4") ||
            lower.endsWith(".aac") -> readM4aExtraTags(path)
            else                    -> mapOf("composer" to null, "comment" to null)
        }
    }

    private fun readMp3ExtraTags(path: String): Map<String, String?> {
        val mp3 = Mp3File(path)
        val composer: String?
        val comment: String?
        when {
            mp3.hasId3v2Tag() -> {
                composer = mp3.id3v2Tag.composer
                comment  = mp3.id3v2Tag.comment
            }
            mp3.hasId3v1Tag() -> {
                composer = null
                comment  = mp3.id3v1Tag.comment
            }
            else -> {
                composer = null
                comment  = null
            }
        }
        return mapOf("composer" to composer?.ifBlank { null },
                     "comment"  to comment?.ifBlank  { null })
    }

    private fun readFlacExtraTags(path: String): Map<String, String?> {
        val comments = parseVorbisComments(File(path).readBytes())
        return mapOf(
            "composer" to comments["COMPOSER"]?.ifBlank { null },
            "comment"  to (comments["COMMENT"] ?: comments["DESCRIPTION"])?.ifBlank { null }
        )
    }

    private fun writeExtraTags(path: String, composer: String?, comment: String?) {
        val lower = path.lowercase()
        when {
            lower.endsWith(".mp3")  -> writeMp3ExtraTags(path, composer, comment)
            lower.endsWith(".flac") -> writeFlacExtraTags(path, composer, comment)
            lower.endsWith(".m4a") || lower.endsWith(".mp4") ||
            lower.endsWith(".aac") -> writeM4aExtraTags(path, composer, comment)
        }
    }

    private fun writeMp3ExtraTags(path: String, composer: String?, comment: String?) {
        val mp3 = Mp3File(path)

        if (!mp3.hasId3v2Tag()) {
            mp3.id3v2Tag = com.mpatric.mp3agic.ID3v24Tag()
            if (mp3.hasId3v1Tag()) {
                mp3.id3v2Tag.title       = mp3.id3v1Tag.title
                mp3.id3v2Tag.artist      = mp3.id3v1Tag.artist
                mp3.id3v2Tag.album       = mp3.id3v1Tag.album
                mp3.id3v2Tag.year        = mp3.id3v1Tag.year
                mp3.id3v2Tag.track       = mp3.id3v1Tag.track
                mp3.id3v2Tag.comment     = mp3.id3v1Tag.comment
            }
        }

        if (composer != null) mp3.id3v2Tag.composer = composer.ifBlank { null }
        if (comment  != null) mp3.id3v2Tag.comment  = comment.ifBlank  { null }

        val tmpPath = "$path.tmp"
        mp3.save(tmpPath)

        val original = File(path)
        val tmp      = File(tmpPath)
        try {
            if (!tmp.renameTo(original)) {
                tmp.copyTo(original, overwrite = true)
            }
        } finally {
            if (tmp.exists()) tmp.delete()
        }
    }

    private fun writeFlacExtraTags(path: String, composer: String?, comment: String?) {
        val file  = File(path)
        val bytes = file.readBytes()
        val info  = findVorbisBlock(bytes)
        ?: throw IllegalStateException("No Vorbis comment block found in FLAC")

        val (blockStart, blockDataStart, blockLen, isLast) = info
        val existing = parseVorbisComments(bytes)

        if (composer != null) {
            if (composer.isBlank()) existing.remove("COMPOSER")
                else                    existing["COMPOSER"] = composer
        }
        if (comment != null) {
            if (comment.isBlank()) { existing.remove("COMMENT"); existing.remove("DESCRIPTION") }
            else                    existing["COMMENT"] = comment
        }

        val newBlock = buildVorbisBlock(existing, isLast)

        val out = ByteArray(blockStart + newBlock.size + (bytes.size - (blockDataStart + blockLen)))
        System.arraycopy(bytes,    0,                 out, 0,                        blockStart)
        System.arraycopy(newBlock, 0,                 out, blockStart,               newBlock.size)
        System.arraycopy(bytes,    blockDataStart + blockLen,
                         out,     blockStart + newBlock.size,
                         bytes.size - (blockDataStart + blockLen))

        val tmpFile = File("$path.tmp")
        try {
            tmpFile.writeBytes(out)
            if (!tmpFile.renameTo(file)) {
                tmpFile.copyTo(file, overwrite = true)
            }
        } finally {
            if (tmpFile.exists()) tmpFile.delete()
        }
    }

    private fun writeAllTagsViaJaudiotagger(path: String, call: io.flutter.plugin.common.MethodCall) {
        val audioFile = AudioFileIO.read(File(path))
        val tag       = audioFile.tagOrCreateDefault

        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        val fieldMap = mapOf(
            "title"       to FieldKey.TITLE,
            "artist"      to FieldKey.ARTIST,
            "album"       to FieldKey.ALBUM,
            "genre"       to FieldKey.GENRE,
            "albumArtist" to FieldKey.ALBUM_ARTIST,
            "lyrics"      to FieldKey.LYRICS,
            "composer"    to FieldKey.COMPOSER,
            "comment"     to FieldKey.COMMENT,
        )
        for ((argKey, fieldKey) in fieldMap) {
            if (args.containsKey(argKey)) {
                val v = args[argKey] as? String
                if (v.isNullOrBlank()) tag.deleteField(fieldKey)
                    else                   tag.setField(fieldKey, v)
            }
        }

        if (args.containsKey("year")) {
            val year = args["year"] as? Int
            if (year == null || year == 0) tag.deleteField(FieldKey.YEAR)
                else                           tag.setField(FieldKey.YEAR, year.toString())
        }
        if (args.containsKey("trackNumber")) {
            val track = args["trackNumber"] as? Int
            if (track == null || track == 0) tag.deleteField(FieldKey.TRACK)
                else                             tag.setField(FieldKey.TRACK, track.toString())
        }
        if (args.containsKey("discNumber")) {
            val disc = args["discNumber"] as? Int
            if (disc == null || disc == 0) tag.deleteField(FieldKey.DISC_NO)
                else                           tag.setField(FieldKey.DISC_NO, disc.toString())
        }

        if (args.containsKey("artworkBytes")) {
            tag.deleteArtworkField()
            @Suppress("UNCHECKED_CAST")
            val artworkBytes = args["artworkBytes"] as? List<Int>
            if (!artworkBytes.isNullOrEmpty()) {
                val bytes   = artworkBytes.map { it.toByte() }.toByteArray()
                val artwork = org.jaudiotagger.tag.images.AndroidArtwork.createArtworkFromFile(
                    createTempArtworkFile(bytes)
                )
                tag.setField(artwork)
            }
        }

        try {
            audioFile.commit()
        } catch (e: Exception) {
            Log.w(TAG, "commit() failed, falling back to AudioFileIO.write(): ${e.message}")
            AudioFileIO.write(audioFile)
        }
    }

    private fun createTempArtworkFile(bytes: ByteArray): File {
        val tmp = File.createTempFile("flacr_art", ".jpg", cacheDir)
        tmp.writeBytes(bytes)
        tmp.deleteOnExit()
        return tmp
    }

    private fun readM4aExtraTags(path: String): Map<String, String?> {
        val audioFile = AudioFileIO.read(File(path))
        val tag = audioFile.tagOrCreateDefault
        return mapOf(
            "composer" to tag.getFirst(FieldKey.COMPOSER).ifBlank { null },
                     "comment"  to tag.getFirst(FieldKey.COMMENT).ifBlank  { null }
        )
    }

    private fun writeM4aExtraTags(path: String, composer: String?, comment: String?) {
        val audioFile = AudioFileIO.read(File(path))
        val tag = audioFile.tagOrCreateDefault
        if (composer != null) {
            if (composer.isBlank()) tag.deleteField(FieldKey.COMPOSER)
                else                    tag.setField(FieldKey.COMPOSER, composer)
        }
        if (comment != null) {
            if (comment.isBlank()) tag.deleteField(FieldKey.COMMENT)
                else                   tag.setField(FieldKey.COMMENT, comment)
        }
        try {
            audioFile.commit()
        } catch (e: Exception) {
            Log.w(TAG, "commit() failed in writeM4aExtraTags, falling back: ${e.message}")
            AudioFileIO.write(audioFile)
        }
    }

    data class VorbisBlockInfo(
        val blockStart:     Int,
        val blockDataStart: Int,
        val blockLen:       Int,
        val isLast:         Boolean
    )

    private fun findVorbisBlock(bytes: ByteArray): VorbisBlockInfo? {
        if (bytes.size < 4) return null
            if (bytes[0] != 0x66.toByte() || bytes[1] != 0x4C.toByte() ||
                bytes[2] != 0x61.toByte() || bytes[3] != 0x43.toByte()) return null

                var pos = 4
                while (pos + 4 <= bytes.size) {
                    val header   = bytes[pos].toInt() and 0xFF
                    val isLast   = (header and 0x80) != 0
                    val blockType = header and 0x7F
                    val blockLen = ((bytes[pos + 1].toInt() and 0xFF) shl 16) or
                    ((bytes[pos + 2].toInt() and 0xFF) shl 8)  or
                    (bytes[pos + 3].toInt() and 0xFF)

                    if (blockType == 4) {
                        return VorbisBlockInfo(
                            blockStart     = pos,
                            blockDataStart = pos + 4,
                            blockLen       = blockLen,
                            isLast         = isLast
                        )
                    }
                    pos += 4 + blockLen
                    if (isLast) break
                }
                return null
    }

    private fun parseVorbisComments(bytes: ByteArray): MutableMap<String, String> {
        val result = mutableMapOf<String, String>()
        val info   = findVorbisBlock(bytes) ?: return result
        val block  = bytes.copyOfRange(info.blockDataStart, info.blockDataStart + info.blockLen)

        var bp = 0
        if (bp + 4 > block.size) return result
            val vendorLen = leInt(block, bp); bp += 4 + vendorLen
            if (bp + 4 > block.size) return result
                val count = leInt(block, bp); bp += 4

                repeat(count) {
                    if (bp + 4 > block.size) return result
                        val len = leInt(block, bp); bp += 4
                        if (bp + len > block.size) return result
                            val raw = String(block, bp, len, Charsets.UTF_8); bp += len
                            val eq  = raw.indexOf('=')
                            if (eq > 0) result[raw.substring(0, eq).uppercase()] = raw.substring(eq + 1)
                }
                return result
    }

    private fun buildVorbisBlock(comments: Map<String, String>, isLast: Boolean): ByteArray {
        val vendorStr   = "flac-r".toByteArray(Charsets.UTF_8)
        val commentBytes = comments.map { (k, v) ->
            "$k=$v".toByteArray(Charsets.UTF_8)
        }

        var dataLen = 4 + vendorStr.size + 4
        for (cb in commentBytes) dataLen += 4 + cb.size

            val data = ByteArray(dataLen)
            var pos  = 0

            leWrite(data, pos, vendorStr.size); pos += 4
            System.arraycopy(vendorStr, 0, data, pos, vendorStr.size); pos += vendorStr.size

            leWrite(data, pos, commentBytes.size); pos += 4
            for (cb in commentBytes) {
                leWrite(data, pos, cb.size); pos += 4
                System.arraycopy(cb, 0, data, pos, cb.size); pos += cb.size
            }

            val header = ByteArray(4)
            header[0] = ((if (isLast) 0x80 else 0x00) or 4).toByte()
            header[1] = ((dataLen shr 16) and 0xFF).toByte()
            header[2] = ((dataLen shr  8) and 0xFF).toByte()
            header[3] = ( dataLen         and 0xFF).toByte()

            return header + data
    }

    private fun leInt(b: ByteArray, offset: Int): Int =
        (b[offset].toInt()     and 0xFF)        or
        ((b[offset+1].toInt()  and 0xFF) shl 8)  or
        ((b[offset+2].toInt()  and 0xFF) shl 16) or
        ((b[offset+3].toInt()  and 0xFF) shl 24)

        private fun leWrite(b: ByteArray, offset: Int, v: Int) {
            b[offset]   = ( v         and 0xFF).toByte()
            b[offset+1] = ((v shr  8) and 0xFF).toByte()
            b[offset+2] = ((v shr 16) and 0xFF).toByte()
            b[offset+3] = ((v shr 24) and 0xFF).toByte()
        }
}
