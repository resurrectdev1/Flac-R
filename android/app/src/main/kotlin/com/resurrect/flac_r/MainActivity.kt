package com.resurrect.flac_r

import android.util.Log
import com.mpatric.mp3agic.Mp3File
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.tag.FieldKey
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
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


        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val taskQueue  = messenger.makeBackgroundTaskQueue()

        MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, taskQueue)
        .setMethodCallHandler { call, result ->
            if (call.method == "readExtraTagsBatch") {
                @Suppress("UNCHECKED_CAST")
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                val batchResult = mutableMapOf<String, Map<String, String?>>()
                for (p in paths) {
                    batchResult[p] = try {
                        readExtraTags(p)
                    } catch (e: Exception) {
                        Log.w(TAG, "readExtraTagsBatch: failed for $p: ${e.message}")
                        mapOf("composer" to null, "comment" to null)
                    }
                }
                result.success(batchResult)
                return@setMethodCallHandler
            }

            if (call.method == "scanFiles") {
                @Suppress("UNCHECKED_CAST")
                val paths = call.argument<List<String>>("paths") ?: emptyList()
                scanFiles(paths)
                result.success(null)
                return@setMethodCallHandler
            }

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
                        val lower = path.lowercase()
                        if (lower.endsWith(".aac")) {
                            writeAllTagsViaMp3agic(path, call)
                        } else {
                            writeAllTagsViaJaudiotagger(path, call)
                        }
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
    
    private fun scanFiles(paths: List<String>) {
        if (paths.isEmpty()) return
            try {
                android.media.MediaScannerConnection.scanFile(
                    applicationContext,
                    paths.toTypedArray(),
                                                              null,
                                                              null,
                )
            } catch (e: Exception) {
                Log.w(TAG, "scanFiles failed for $paths: ${e.message}")
            }
    }

    private fun readExtraTags(path: String): Map<String, String?> {
        val lower = path.lowercase()
        return when {
            lower.endsWith(".mp3")  -> readMp3ExtraTags(path)
            lower.endsWith(".aac")  -> readAacExtraTags(path)
            lower.endsWith(".flac") ||
            lower.endsWith(".ogg")  -> readFlacExtraTags(path)
            lower.endsWith(".opus") -> readOpusExtraTags(path)
            lower.endsWith(".m4a")  -> readM4aExtraTags(path)
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
            lower.endsWith(".aac")  -> writeAacExtraTags(path, composer, comment)
            lower.endsWith(".flac") ||
            lower.endsWith(".ogg")  -> writeFlacExtraTags(path, composer, comment)
            lower.endsWith(".opus") -> writeOpusExtraTags(path, composer, comment)
            lower.endsWith(".m4a")  -> writeM4aExtraTags(path, composer, comment)
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

    private data class Id3v2Frame(val id: String, val flags: Int, val data: ByteArray)
        private data class Id3v2Tag(val majorVersion: Int, val frames: List<Id3v2Frame>, val tagTotalLen: Int)

            private fun beInt(b: ByteArray, offset: Int): Int =
                ((b[offset].toInt()     and 0xFF) shl 24) or
                ((b[offset + 1].toInt() and 0xFF) shl 16) or
                ((b[offset + 2].toInt() and 0xFF) shl 8)  or
                ( b[offset + 3].toInt() and 0xFF)

                private fun intToBe(v: Int): ByteArray = byteArrayOf(
                    ((v shr 24) and 0xFF).toByte(),
                                                                     ((v shr 16) and 0xFF).toByte(),
                                                                     ((v shr  8) and 0xFF).toByte(),
                                                                     ( v         and 0xFF).toByte(),
                )

                    private fun synchsafeToInt(b: ByteArray, offset: Int): Int =
                        ((b[offset].toInt()     and 0x7F) shl 21) or
                        ((b[offset + 1].toInt() and 0x7F) shl 14) or
                        ((b[offset + 2].toInt() and 0x7F) shl 7)  or
                        ( b[offset + 3].toInt() and 0x7F)

                        private fun intToSynchsafe(v: Int): ByteArray = byteArrayOf(
                            ((v shr 21) and 0x7F).toByte(),
                                                                                    ((v shr 14) and 0x7F).toByte(),
                                                                                    ((v shr  7) and 0x7F).toByte(),
                                                                                    ( v         and 0x7F).toByte(),
                        )

                            private fun deunsyncId3(data: ByteArray): ByteArray {
                                val out = java.io.ByteArrayOutputStream(data.size)
                                var i = 0
                                while (i < data.size) {
                                    out.write(data[i].toInt())
                                    i += if (data[i] == 0xFF.toByte() && i + 1 < data.size && data[i + 1] == 0x00.toByte()) 2 else 1
                                }
                                return out.toByteArray()
                            }

                            private fun parseId3v2Tag(bytes: ByteArray): Id3v2Tag? {
                                if (bytes.size < 10) return null
                                    if (bytes[0] != 'I'.code.toByte() || bytes[1] != 'D'.code.toByte() || bytes[2] != '3'.code.toByte()) return null

                                        val majorVersion = bytes[3].toInt() and 0xFF
                                        val flags        = bytes[5].toInt() and 0xFF
                                        val unsync       = (flags and 0x80) != 0
                                        val hasExtHeader = (flags and 0x40) != 0
                                        val hasFooter    = (flags and 0x10) != 0
                                        val size         = synchsafeToInt(bytes, 6)
                                        val tagTotalLen  = 10 + size + (if (hasFooter) 10 else 0)
                                        if (size < 0 || tagTotalLen > bytes.size) return null

                                            var body = bytes.copyOfRange(10, 10 + size)
                                            if (unsync) body = deunsyncId3(body)

                                                var pos = 0
                                                if (hasExtHeader && body.size >= 4) {
                                                    pos = if (majorVersion >= 4) synchsafeToInt(body, 0) else 4 + beInt(body, 0)
                                                    if (pos < 0 || pos > body.size) pos = body.size
                                                }

                                                val frames = mutableListOf<Id3v2Frame>()
                                                while (pos + 10 <= body.size) {
                                                    if (body[pos] == 0.toByte()) break
                                                        val id = String(body.copyOfRange(pos, pos + 4), Charsets.US_ASCII)
                                                        val frameSize = if (majorVersion >= 4) synchsafeToInt(body, pos + 4) else beInt(body, pos + 4)
                                                        val frameFlags = ((body[pos + 8].toInt() and 0xFF) shl 8) or (body[pos + 9].toInt() and 0xFF)
                                                        val dataStart = pos + 10
                                                        if (frameSize < 0 || dataStart + frameSize > body.size) break

                                                            var frameData = body.copyOfRange(dataStart, dataStart + frameSize)
                                                            if (majorVersion >= 4 && (frameFlags and 0x0002) != 0) frameData = deunsyncId3(frameData)
                                                                frames.add(Id3v2Frame(id, frameFlags, frameData))
                                                                pos = dataStart + frameSize
                                                }

                                                return Id3v2Tag(majorVersion, frames, tagTotalLen)
                            }

                            private fun decodeId3Text(data: ByteArray, start: Int, end: Int, encoding: Int): String {
                                if (start >= end) return ""
                                    val slice = data.copyOfRange(start, end)
                                    val charset = when (encoding) {
                                        0 -> Charsets.ISO_8859_1
                                        1 -> Charsets.UTF_16
                                        2 -> Charsets.UTF_16BE
                                        3 -> Charsets.UTF_8
                                        else -> Charsets.ISO_8859_1
                                    }
                                    return String(slice, charset).trimEnd('\u0000')
                            }

                            private fun decodeTcomFrame(data: ByteArray): String {
                                if (data.isEmpty()) return ""
                                    val encoding = data[0].toInt() and 0xFF
                                    return decodeId3Text(data, 1, data.size, encoding)
                            }

                            private fun decodeCommFrame(data: ByteArray): String {
                                if (data.size < 4) return ""
                                    val encoding = data[0].toInt() and 0xFF
                                    val wide = encoding == 1 || encoding == 2
                                    var i = 4
                                    while (i < data.size) {
                                        if (wide) {
                                            if (i + 1 < data.size && data[i] == 0.toByte() && data[i + 1] == 0.toByte()) { i += 2; break }
                                            i += 2
                                        } else {
                                            if (data[i] == 0.toByte()) { i += 1; break }
                                            i += 1
                                        }
                                    }
                                    return decodeId3Text(data, minOf(i, data.size), data.size, encoding)
                            }

                            private fun canEncodeLatin1(s: String): Boolean = s.all { it.code <= 0xFF }
                            private fun chooseId3Encoding(text: String, majorVersion: Int): Int {
                                if (canEncodeLatin1(text)) return 0
                                    return if (majorVersion >= 4) 3 else 1
                            }

                            private fun encodeId3Text(text: String, encoding: Int): ByteArray = when (encoding) {
                                0 -> text.toByteArray(Charsets.ISO_8859_1)
                                1 -> text.toByteArray(Charsets.UTF_16)
                                else -> text.toByteArray(Charsets.UTF_8)
                            }

                            private fun buildTcomFrameData(text: String, encoding: Int): ByteArray =
                                byteArrayOf(encoding.toByte()) + encodeId3Text(text, encoding)

                                private fun buildCommFrameData(text: String, encoding: Int): ByteArray {
                                    val lang = "eng".toByteArray(Charsets.US_ASCII)
                                    val descTerminator = if (encoding == 1 || encoding == 2) byteArrayOf(0, 0) else byteArrayOf(0)
                                    return byteArrayOf(encoding.toByte()) + lang + descTerminator + encodeId3Text(text, encoding)
                                }

                                private fun buildId3Frame(id: String, data: ByteArray, majorVersion: Int, flags: Int = 0): ByteArray {
                                    val sizeBytes = if (majorVersion >= 4) intToSynchsafe(data.size) else intToBe(data.size)
                                    val header = ByteArray(10)
                                    System.arraycopy(id.toByteArray(Charsets.US_ASCII), 0, header, 0, 4)
                                    System.arraycopy(sizeBytes, 0, header, 4, 4)
                                    header[8] = ((flags shr 8) and 0xFF).toByte()
                                    header[9] = ( flags        and 0xFF).toByte()
                                    return header + data
                                }

                                private fun readId3v1Comment(bytes: ByteArray): String? {
                                    if (bytes.size < 128) return null
                                        val tail = bytes.copyOfRange(bytes.size - 128, bytes.size)
                                        if (tail[0] != 'T'.code.toByte() || tail[1] != 'A'.code.toByte() || tail[2] != 'G'.code.toByte()) return null
                                            val commentBytes = tail.copyOfRange(97, 127)
                                            val text = String(commentBytes, Charsets.ISO_8859_1).trimEnd('\u0000', ' ')
                                            return text.ifBlank { null }
                                }

                                private fun readAacExtraTags(path: String): Map<String, String?> {
                                    val bytes = File(path).readBytes()
                                    val tag = parseId3v2Tag(bytes)
                                    val composer = tag?.frames?.firstOrNull { it.id == "TCOM" }?.let { decodeTcomFrame(it.data) }?.ifBlank { null }
                                    val commentFromV2 = tag?.frames?.firstOrNull { it.id == "COMM" }?.let { decodeCommFrame(it.data) }?.ifBlank { null }
                                    val comment = commentFromV2 ?: readId3v1Comment(bytes)
                                    return mapOf("composer" to composer, "comment" to comment)
                                }

                                private fun writeAacExtraTags(path: String, composer: String?, comment: String?) {
                                    val file  = File(path)
                                    val bytes = file.readBytes()
                                    val existing = parseId3v2Tag(bytes)
                                    val majorVersion = existing?.majorVersion?.coerceAtLeast(3) ?: 4
                                    val keptFrames = (existing?.frames ?: emptyList()).filter { it.id != "TCOM" && it.id != "COMM" }

                                    val existingComposer = existing?.frames?.firstOrNull { it.id == "TCOM" }?.let { decodeTcomFrame(it.data) }
                                    val existingComment  = existing?.frames?.firstOrNull { it.id == "COMM" }?.let { decodeCommFrame(it.data) }

                                    val finalComposer = when {
                                        composer == null   -> existingComposer
                                        composer.isBlank() -> null
                                        else                -> composer
                                    }
                                    val finalComment = when {
                                        comment == null   -> existingComment
                                        comment.isBlank() -> null
                                        else                -> comment
                                    }

                                    val frameBytesList = mutableListOf<ByteArray>()
                                    for (f in keptFrames) {
                                        val preservedFlags = f.flags and 0x0002.inv()
                                        frameBytesList.add(buildId3Frame(f.id, f.data, majorVersion, preservedFlags))
                                    }
                                    if (!finalComposer.isNullOrEmpty()) {
                                        val enc = chooseId3Encoding(finalComposer, majorVersion)
                                        frameBytesList.add(buildId3Frame("TCOM", buildTcomFrameData(finalComposer, enc), majorVersion))
                                    }
                                    if (!finalComment.isNullOrEmpty()) {
                                        val enc = chooseId3Encoding(finalComment, majorVersion)
                                        frameBytesList.add(buildId3Frame("COMM", buildCommFrameData(finalComment, enc), majorVersion))
                                    }

                                    val bodySize = frameBytesList.sumOf { it.size }
                                    val header = ByteArray(10)
                                    header[0] = 'I'.code.toByte(); header[1] = 'D'.code.toByte(); header[2] = '3'.code.toByte()
                                    header[3] = majorVersion.toByte()
                                    header[4] = 0
                                    header[5] = 0
                                    System.arraycopy(intToSynchsafe(bodySize), 0, header, 6, 4)

                                    val out = java.io.ByteArrayOutputStream()
                                    out.write(header)
                                    for (fb in frameBytesList) out.write(fb)

                                        val restStart = existing?.tagTotalLen ?: 0
                                        out.write(bytes, restStart, bytes.size - restStart)

                                        val tmpFile = File("$path.tmp")
                                        try {
                                            tmpFile.writeBytes(out.toByteArray())
                                            if (!tmpFile.renameTo(file)) {
                                                tmpFile.copyTo(file, overwrite = true)
                                            }
                                        } finally {
                                            if (tmpFile.exists()) tmpFile.delete()
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

                                    val isOgg = path.lowercase().endsWith(".ogg")
                                    val isAac = path.lowercase().endsWith(".aac")
                                    if (!isOgg && !isAac && args.containsKey("artworkBytes")) {
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

                                private fun writeAllTagsViaMp3agic(path: String, call: io.flutter.plugin.common.MethodCall) {
                                    val mp3 = Mp3File(path)

                                    if (!mp3.hasId3v2Tag()) {
                                        mp3.id3v2Tag = com.mpatric.mp3agic.ID3v24Tag()
                                        if (mp3.hasId3v1Tag()) {
                                            mp3.id3v2Tag.title   = mp3.id3v1Tag.title
                                            mp3.id3v2Tag.artist  = mp3.id3v1Tag.artist
                                            mp3.id3v2Tag.album   = mp3.id3v1Tag.album
                                            mp3.id3v2Tag.year    = mp3.id3v1Tag.year
                                            mp3.id3v2Tag.track   = mp3.id3v1Tag.track
                                            mp3.id3v2Tag.comment = mp3.id3v1Tag.comment
                                        }
                                    }

                                    @Suppress("UNCHECKED_CAST")
                                    val args = call.arguments as Map<String, Any?>

                                    if (args.containsKey("title"))       mp3.id3v2Tag.title    = (args["title"]       as? String)?.ifBlank { null }
                                    if (args.containsKey("artist"))      mp3.id3v2Tag.artist   = (args["artist"]      as? String)?.ifBlank { null }
                                    if (args.containsKey("album"))       mp3.id3v2Tag.album    = (args["album"]       as? String)?.ifBlank { null }
                                    if (args.containsKey("year"))        mp3.id3v2Tag.year     = (args["year"]        as? Int)?.takeIf { it != 0 }?.toString()
                                        if (args.containsKey("genre"))       mp3.id3v2Tag.genreDescription = (args["genre"] as? String)?.ifBlank { null }
                                        if (args.containsKey("trackNumber")) mp3.id3v2Tag.track    = (args["trackNumber"] as? Int)?.takeIf { it != 0 }?.toString()
                                            if (args.containsKey("albumArtist")) mp3.id3v2Tag.albumArtist = (args["albumArtist"] as? String)?.ifBlank { null }
                                            if (args.containsKey("composer"))    mp3.id3v2Tag.composer = (args["composer"]    as? String)?.ifBlank { null }
                                            if (args.containsKey("comment"))     mp3.id3v2Tag.comment  = (args["comment"]     as? String)?.ifBlank { null }
                                            if (args.containsKey("lyrics"))      mp3.id3v2Tag.lyrics   = (args["lyrics"]      as? String)?.ifBlank { null }

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
                                    val info  = findVorbisBlock(bytes) ?: return mutableMapOf()
                                    val block = bytes.copyOfRange(info.blockDataStart, info.blockDataStart + info.blockLen)
                                    return decodeCommentList(block)
                                }

                                private fun buildVorbisBlock(comments: Map<String, String>, isLast: Boolean): ByteArray {
                                    val data   = encodeCommentList(comments)
                                    val dataLen = data.size

                                    val header = ByteArray(4)
                                    header[0] = ((if (isLast) 0x80 else 0x00) or 4).toByte()
                                    header[1] = ((dataLen shr 16) and 0xFF).toByte()
                                    header[2] = ((dataLen shr  8) and 0xFF).toByte()
                                    header[3] = ( dataLen         and 0xFF).toByte()

                                    return header + data
                                }

                                private fun decodeCommentList(block: ByteArray): MutableMap<String, String> {
                                    val result = mutableMapOf<String, String>()
                                    var bp = 0
                                    if (bp + 4 > block.size) return result
                                        val vendorLen = leInt(block, bp); bp += 4 + vendorLen
                                        if (vendorLen < 0 || bp > block.size || bp + 4 > block.size) return result
                                            val count = leInt(block, bp); bp += 4

                                            repeat(count) {
                                                if (bp + 4 > block.size) return result
                                                    val len = leInt(block, bp); bp += 4
                                                    if (len < 0 || bp + len > block.size) return result
                                                        val raw = String(block, bp, len, Charsets.UTF_8); bp += len
                                                        val eq  = raw.indexOf('=')
                                                        if (eq > 0) result[raw.substring(0, eq).uppercase()] = raw.substring(eq + 1)
                                            }
                                            return result
                                }

                                private fun encodeCommentList(comments: Map<String, String>): ByteArray {
                                    val vendorStr    = "flac-r".toByteArray(Charsets.UTF_8)
                                    val commentBytes = comments.map { (k, v) -> "$k=$v".toByteArray(Charsets.UTF_8) }

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
                                        return data
                                }

                                private val OPUS_TAGS_MAGIC = "OpusTags".toByteArray(Charsets.UTF_8)
                                private val OPUS_HEAD_MAGIC = "OpusHead".toByteArray(Charsets.UTF_8)

                                private data class OggPage(
                                    val headerStart:  Int,
                                    val totalLen:     Int,
                                    val payloadStart: Int,
                                    val payloadLen:   Int,
                                    val serial:       Int,
                                    val pageSeq:      Int,
                                    val granule:      Long,
                                    val headerType:   Int,
                                    val segmentTable: IntArray,
                                )

                                private fun bytesEqual(a: ByteArray, aOffset: Int, b: ByteArray): Boolean {
                                    if (aOffset + b.size > a.size) return false
                                        for (i in b.indices) if (a[aOffset + i] != b[i]) return false
                                            return true
                                }

                                private fun leLong(b: ByteArray, offset: Int): Long {
                                    var v = 0L
                                    for (i in 0 until 8) v = v or ((b[offset + i].toLong() and 0xFFL) shl (8 * i))
                                        return v
                                }

                                private fun parseOggPageAt(bytes: ByteArray, offset: Int): OggPage? {
                                    if (offset + 27 > bytes.size) return null
                                        if (!bytesEqual(bytes, offset, "OggS".toByteArray(Charsets.US_ASCII))) return null

                                            val headerType    = bytes[offset + 5].toInt() and 0xFF
                                            val granule       = leLong(bytes, offset + 6)
                                            val serial        = leInt(bytes, offset + 14)
                                            val pageSeq       = leInt(bytes, offset + 18)
                                            val pageSegments  = bytes[offset + 26].toInt() and 0xFF
                                            val segTableStart = offset + 27
                                            if (segTableStart + pageSegments > bytes.size) return null

                                                val segmentTable = IntArray(pageSegments) { bytes[segTableStart + it].toInt() and 0xFF }
                                                val payloadLen   = segmentTable.sum()
                                                val payloadStart = segTableStart + pageSegments
                                                if (payloadStart + payloadLen > bytes.size) return null

                                                    return OggPage(
                                                        headerStart  = offset,
                                                        totalLen     = (payloadStart + payloadLen) - offset,
                                                                   payloadStart = payloadStart,
                                                                   payloadLen   = payloadLen,
                                                                   serial       = serial,
                                                                   pageSeq      = pageSeq,
                                                                   granule      = granule,
                                                                   headerType   = headerType,
                                                                   segmentTable = segmentTable,
                                                    )
                                }
                                
                                private fun lacingFor(length: Int): IntArray {
                                    val segs = mutableListOf<Int>()
                                    var remaining = length
                                    while (remaining >= 255) { segs.add(255); remaining -= 255 }
                                    segs.add(remaining)
                                    return segs.toIntArray()
                                }

                                private fun paginateSegments(segments: List<Int>, maxPerPage: Int = 255): List<List<Int>> {
                                    if (segments.isEmpty()) return listOf(emptyList())
                                        val chunks = mutableListOf<List<Int>>()
                                        var i = 0
                                        while (i < segments.size) {
                                            val end = minOf(i + maxPerPage, segments.size)
                                            chunks.add(segments.subList(i, end))
                                            i = end
                                        }
                                        return chunks
                                }

                                private data class CommentPacketLocation(
                                    val bytes:            ByteArray,
                                    val endPageIdx:       Int,
                                    val consumedSegCount: Int,
                                    val consumedByteCount: Int,
                                )

                                private fun locateFirstPacket(pages: List<OggPage>, bytes: ByteArray): CommentPacketLocation? {
                                    val out = java.io.ByteArrayOutputStream()
                                    for (pageIdx in pages.indices) {
                                        val page = pages[pageIdx]
                                        var consumedBytes = 0
                                        var consumedSegs  = 0
                                        for (seg in page.segmentTable) {
                                            out.write(bytes, page.payloadStart + consumedBytes, seg)
                                            consumedBytes += seg
                                            consumedSegs++
                                            if (seg < 255) {
                                                return CommentPacketLocation(out.toByteArray(), pageIdx, consumedSegs, consumedBytes)
                                            }
                                        }
                                    }
                                    return null
                                }

                                private fun collectOpusPages(bytes: ByteArray): Pair<OggPage, List<OggPage>>? {
                                    val head = parseOggPageAt(bytes, 0) ?: return null
                                    if (head.payloadLen < 8 || !bytesEqual(bytes, head.payloadStart, OPUS_HEAD_MAGIC)) return null

                                        val pages = mutableListOf<OggPage>()
                                        var offset = head.headerStart + head.totalLen
                                        while (offset < bytes.size) {
                                            val p = parseOggPageAt(bytes, offset) ?: return null
                                            if (p.totalLen <= 0) return null
                                                if (p.serial == head.serial) pages.add(p)
                                                    offset += p.totalLen
                                        }
                                        return head to pages
                                }

                                private fun readOpusExtraTags(path: String): Map<String, String?> {
                                    val bytes = File(path).readBytes()
                                    val (_, pages) = collectOpusPages(bytes) ?: return mapOf("composer" to null, "comment" to null)
                                    val loc = locateFirstPacket(pages, bytes) ?: return mapOf("composer" to null, "comment" to null)
                                    if (loc.bytes.size < 8 || !bytesEqual(loc.bytes, 0, OPUS_TAGS_MAGIC)) {
                                        return mapOf("composer" to null, "comment" to null)
                                    }

                                    val comments = decodeCommentList(loc.bytes.copyOfRange(8, loc.bytes.size))
                                    return mapOf(
                                        "composer" to comments["COMPOSER"]?.ifBlank { null },
                                        "comment"  to (comments["COMMENT"] ?: comments["DESCRIPTION"])?.ifBlank { null }
                                    )
                                }

                                private fun buildOggPage(
                                    serial: Int, pageSeq: Int, granule: Long, headerType: Int,
                                    segments: List<Int>, payload: ByteArray,
                                ): ByteArray {
                                    val page = ByteArray(27 + segments.size + payload.size)
                                    page[0] = 'O'.code.toByte(); page[1] = 'g'.code.toByte()
                                    page[2] = 'g'.code.toByte(); page[3] = 'S'.code.toByte()
                                    page[4] = 0
                                    page[5] = headerType.toByte()
                                    for (i in 0 until 8) page[6 + i]  = ((granule  shr (8 * i)) and 0xFFL).toByte()
                                        for (i in 0 until 4) page[14 + i] = ((serial   shr (8 * i)) and 0xFF).toByte()
                                            for (i in 0 until 4) page[18 + i] = ((pageSeq  shr (8 * i)) and 0xFF).toByte()
                                                page[26] = segments.size.toByte()
                                                for (i in segments.indices) page[27 + i] = segments[i].toByte()
                                                    System.arraycopy(payload, 0, page, 27 + segments.size, payload.size)

                                                    val crc = oggCrc32(page)
                                                    page[22] = ( crc         and 0xFF).toByte()
                                                    page[23] = ((crc shr  8) and 0xFF).toByte()
                                                    page[24] = ((crc shr 16) and 0xFF).toByte()
                                                    page[25] = ((crc shr 24) and 0xFF).toByte()
                                                    return page
                                }

                                private fun rewritePageSequenceNumber(bytes: ByteArray, page: OggPage, newSeq: Int): ByteArray {
                                    val raw = bytes.copyOfRange(page.headerStart, page.headerStart + page.totalLen)
                                    raw[18] = ( newSeq         and 0xFF).toByte()
                                    raw[19] = ((newSeq shr  8) and 0xFF).toByte()
                                    raw[20] = ((newSeq shr 16) and 0xFF).toByte()
                                    raw[21] = ((newSeq shr 24) and 0xFF).toByte()
                                    raw[22] = 0; raw[23] = 0; raw[24] = 0; raw[25] = 0
                                    val crc = oggCrc32(raw)
                                    raw[22] = ( crc         and 0xFF).toByte()
                                    raw[23] = ((crc shr  8) and 0xFF).toByte()
                                    raw[24] = ((crc shr 16) and 0xFF).toByte()
                                    raw[25] = ((crc shr 24) and 0xFF).toByte()
                                    return raw
                                }

                                private fun writeOpusExtraTags(path: String, composer: String?, comment: String?) {
                                    val file  = File(path)
                                    val bytes = file.readBytes()

                                    val (head, pages) = collectOpusPages(bytes)
                                    ?: throw IllegalStateException("Not a valid Opus file (missing OpusHead): $path")
                                    if (pages.isEmpty()) throw IllegalStateException("No pages found after OpusHead in $path")

                                        val loc = locateFirstPacket(pages, bytes)
                                        ?: throw IllegalStateException("OpusTags packet never terminates (truncated file?): $path")
                                        if (loc.bytes.size < 8 || !bytesEqual(loc.bytes, 0, OPUS_TAGS_MAGIC)) {
                                            throw IllegalStateException("Expected OpusTags packet immediately after OpusHead: $path")
                                        }

                                        val existing = decodeCommentList(loc.bytes.copyOfRange(8, loc.bytes.size))
                                        if (composer != null) {
                                            if (composer.isBlank()) existing.remove("COMPOSER")
                                                else                    existing["COMPOSER"] = composer
                                        }
                                        if (comment != null) {
                                            if (comment.isBlank()) { existing.remove("COMMENT"); existing.remove("DESCRIPTION") }
                                            else                    existing["COMMENT"] = comment
                                        }
                                        val newCommentPacket = OPUS_TAGS_MAGIC + encodeCommentList(existing)
                                        val finalPage = pages[loc.endPageIdx]
                                        val tailSegments = finalPage.segmentTable.drop(loc.consumedSegCount)
                                        val tailBytes = bytes.copyOfRange(
                                            finalPage.payloadStart + loc.consumedByteCount,
                                            finalPage.payloadStart + finalPage.payloadLen,
                                        )

                                        val commentSegments  = lacingFor(newCommentPacket.size).toList()
                                        val combinedSegments = commentSegments + tailSegments
                                        val combinedBytes    = newCommentPacket + tailBytes

                                        val commentTerminatesAt = commentSegments.size - 1
                                        val tailTermRel = tailSegments.indexOfFirst { it < 255 }
                                        val tailTerminatesAt = if (tailTermRel == -1) -1 else commentSegments.size + tailTermRel

                                        val pageChunks = paginateSegments(combinedSegments)

                                        val newPages = mutableListOf<ByteArray>()
                                        var segCursor  = 0
                                        var byteCursor = 0
                                        for ((chunkIdx, chunkSegs) in pageChunks.withIndex()) {
                                            val chunkByteLen = chunkSegs.sum()
                                            val chunkBytes   = combinedBytes.copyOfRange(byteCursor, byteCursor + chunkByteLen)

                                            val continuesPrev = chunkIdx > 0 && pageChunks[chunkIdx - 1].last() == 255
                                            val segEndExclusive = segCursor + chunkSegs.size
                                            val hasCommentEnd = commentTerminatesAt in segCursor until segEndExclusive
                                            val hasTailEnd    = tailTerminatesAt != -1 && tailTerminatesAt in segCursor until segEndExclusive

                                            val granule = when {
                                                hasTailEnd    -> finalPage.granule
                                                hasCommentEnd -> 0L
                                                else          -> -1L
                                            }

                                            newPages.add(buildOggPage(
                                                serial     = head.serial,
                                                pageSeq    = head.pageSeq + 1 + chunkIdx,
                                                granule    = granule,
                                                headerType = if (continuesPrev) 0x01 else 0x00,
                                                                      segments   = chunkSegs,
                                                                      payload    = chunkBytes,
                                            ))

                                            segCursor  += chunkSegs.size
                                            byteCursor += chunkByteLen
                                        }

                                        val trailingPages = pages.drop(loc.endPageIdx + 1)
                                        val out = java.io.ByteArrayOutputStream()
                                        out.write(bytes, 0, head.headerStart + head.totalLen)
                                        for (np in newPages) out.write(np)

                                            if (trailingPages.isEmpty()) {
                                            } else if (newPages.size == loc.endPageIdx + 1) {
                                                for (tp in trailingPages) out.write(bytes, tp.headerStart, tp.totalLen)
                                            } else {
                                                val newFirstTrailingSeq = head.pageSeq + 1 + newPages.size
                                                val oldFirstTrailingSeq = trailingPages.first().pageSeq
                                                for (tp in trailingPages) {
                                                    val newSeq = tp.pageSeq + (newFirstTrailingSeq - oldFirstTrailingSeq)
                                                    out.write(rewritePageSequenceNumber(bytes, tp, newSeq))
                                                }
                                            }

                                            val tmpFile = File("$path.tmp")
                                            try {
                                                tmpFile.writeBytes(out.toByteArray())
                                                if (!tmpFile.renameTo(file)) {
                                                    tmpFile.copyTo(file, overwrite = true)
                                                }
                                            } finally {
                                                if (tmpFile.exists()) tmpFile.delete()
                                            }
                                }

                                private val oggCrcTable: IntArray by lazy {
                                    IntArray(256) { i ->
                                        var r = i shl 24
                                        repeat(8) {
                                            r = if ((r and 0x80000000.toInt()) != 0) (r shl 1) xor 0x04c11db7 else (r shl 1)
                                        }
                                        r
                                    }
                                }

                                private fun oggCrc32(data: ByteArray): Int {
                                    var crc = 0
                                    for (b in data) {
                                        crc = (crc shl 8) xor oggCrcTable[((crc ushr 24) xor (b.toInt() and 0xFF)) and 0xFF]
                                    }
                                    return crc
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
