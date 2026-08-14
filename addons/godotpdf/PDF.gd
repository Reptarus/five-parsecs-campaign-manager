extends Control

var _xref = []
var _xrefOffset = 0
var _pages = []
var _fonts = []
var _fontList = []
var _title = ""
var _creator = ""
var _pageSize = Vector2i(612, 792)

class _text:
	# LOCAL PATCH (Five Parsecs, Aug 9 2026) — `renderMode` is the PDF `Tr`
	# operator. 0 = fill (upstream's only behaviour), 3 = INVISIBLE, which is how
	# a searchable text layer is laid over a raster without altering the picture.
	func _init(text="", size=12, position=Vector2i(0,0), font="Helvetica", renderMode=0) -> void:
		self.text = text
		self.fontSize = size
		self.position = position
		self.font = font
		self.renderMode = renderMode
	var text = ""
	var fontSize = 12
	var position = Vector2i(0,0)
	var font = "Helvetica"
	var renderMode = 0

class _box:
	func _init(position=Vector2i(0,0), size=Vector2i(0,0), border=Color(0.0,0.0,0.0,1.0), fill=Color(0.0,0.0,0.0,1.0), borderWidth=10) -> void:
		self.size = size
		self.position = position
		self.fill = fill
		self.border = border
		self.borderWidth = borderWidth
	var size = Vector2i(0,0)
	var position = Vector2i(0,0)
	var fill = null
	var border = null
	var borderWidth = 10

class _image:
	# LOCAL PATCH (Five Parsecs, Aug 9 2026) — `drawSize` decouples the image's
	# PIXEL resolution (`size`, which becomes /Width and /Height) from the POINT
	# rect it is painted into on the page (`drawSize`, which becomes the `cm`
	# matrix). Upstream used one value for both, which pins every embedded image
	# to exactly 72 DPI. Defaults to `size`, so upstream callers are unaffected.
	func _init(position=Vector2i(0,0), size=Vector2i(0,0), data="", format=Image.FORMAT_RGBA8, drawSize=null) -> void:
		self.position = position
		self.size = size
		self.dataStream = data
		self.format = format
		self.drawSize = size if drawSize == null else drawSize
	var position = Vector2i(0,0)
	var size = Vector2i(0,0)
	var drawSize = Vector2i(0,0)
	var dataStream = ""
	var format=Image.FORMAT_RGBA8

class _page:
	var text = []
	var boxes = []
	var images = []

class _font:
	func _init(name, path) -> void:
		self.fontName = name
		self.fontPath = path
	var fontName = ""
	var fontPath = ""

func newPDF(t="", c=""):
	_pages = [_page.new()]
	_title = t
	_creator = c
	_fontList = ["Helvetica"]
	_fonts = []

func setTitle(t):
	_title = t

func setCreator(c):
	_creator = c

## LOCAL PATCH (Five Parsecs, Aug 9 2026) — public page-size setter.
##
## `_pageSize` was fixed at US Letter PORTRAIT (612x792) with no way to change it,
## so a landscape document could only be letterboxed into a portrait page: our 3:2
## crew sheet occupied a 612x408 band of a 612x792 page with ~47% of the page blank
## above and below, and the reader opened zoomed out to fit the paper, not the sheet.
##
## Size is in POINTS (72 = 1 inch), so US Letter landscape is Vector2i(792, 612).
## Everything that places content already derives from `_pageSize` (the Y flip in
## newLabel/newBox/newImage, and /MediaBox), so this is the only knob needed.
## Call BEFORE placing content — placement bakes the flip in at call time.
func setPageSize(size) -> bool:
	if size is Vector2:
		size = Vector2i(size)
	if not size is Vector2i or size.x <= 0 or size.y <= 0:
		return false
	_pageSize = size
	return true

func newPage() -> bool:
	_pages.append(_page.new())
	return true

## LOCAL PATCH (Five Parsecs, Aug 9 2026) — text render mode for subsequent labels.
##
## 0 = fill (upstream behaviour, visible), 3 = invisible. Set 3 to lay a
## searchable/selectable text layer over an embedded image without changing a
## single printed pixel — the technique a scanner's OCR layer uses.
var _textRenderMode = 0

func setTextRenderMode(mode : int) -> bool:
	if mode < 0 or mode > 7:
		return false
	_textRenderMode = mode
	return true


## LOCAL PATCH (Five Parsecs, Aug 9 2026) — escape a PDF literal string.
##
## Upstream concatenates label text straight into `(text) Tj`, so ANY of `(`, `)`
## or `\` in user data corrupts the file: an unbalanced `)` terminates the string
## early, and the rest of the label is then parsed as operators. A crew member
## named "Vance (Doc) Ryu" is enough. Backslash must go first or it re-escapes
## the escapes this adds.
static func escapePdfText(raw : String) -> String:
	return raw.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


func newLabel(pageNum : int, labelPosition, labelText : String, labelSize=12, font="Helvetica") -> bool:
	if labelPosition is Vector2:
		labelPosition = Vector2i(labelPosition)
	if not labelPosition is Vector2i:
		return false
	var label = _text.new(labelText, labelSize, Vector2i(labelPosition.x, _pageSize.y-labelPosition.y), font, _textRenderMode)
	_pages[pageNum-1].text.append(label)
	return true

func newBox(pageNum : int, boxPosition, boxSize, fill = Color(0.0,0.0,0.0,1.0), border=null, borderWidth : int = 2) -> bool:
	if boxPosition is Vector2:
		boxPosition = Vector2i(boxPosition)
	if not boxPosition is Vector2i:
		return false
	if boxSize is Vector2:
		boxSize = Vector2i(boxSize)
	if not boxSize is Vector2i:
		return false
	if fill != null and not fill is Color:
		return false
	if border != null and not border is Color:
		return false
	var box = _box.new(Vector2i(boxPosition.x, _pageSize.y-boxPosition.y-boxSize.y), boxSize, border, fill, borderWidth)
	_pages[pageNum-1].boxes.append(box)
	return true

## LOCAL PATCH (Five Parsecs, Aug 9 2026) — optional `drawSize`.
##
## Upstream treats `imageSize` as both the pixel size to resize to AND the point
## rect to paint into. Because 1 point = 1/72 inch, that pins every embedded
## image to 72 DPI: our 2764x1843 sheet was being downsampled to 612x408 before
## it was ever written, so the "print" in Print Sheet came out at screen quality.
##
## Pass `drawSize` to keep the source pixels and paint them into a smaller point
## rect instead. `imageSize` then means "resize the pixels to this" — pass the
## image's own size (or null) to resample nothing at all.
func newImage(pageNum : int, imagePosition, baseImage : Image, imageSize = null, drawSize = null):
	if baseImage == null or (baseImage.get_format() != Image.FORMAT_RGB8 and baseImage.get_format() != Image.FORMAT_RGBA8):
		return false
	if imagePosition is Vector2:
		imagePosition = Vector2i(imagePosition)
	if not imagePosition is Vector2i:
		return false
	if imageSize == null:
		imageSize = baseImage.get_size()
	if imageSize is Vector2:
		imageSize = Vector2i(imageSize)
	if not imageSize is Vector2i:
		return false
	# Points the image occupies on the page. Defaults to the pixel size, which is
	# upstream's behaviour (and therefore 72 DPI).
	if drawSize == null:
		drawSize = imageSize
	if drawSize is Vector2:
		drawSize = Vector2i(drawSize)
	if not drawSize is Vector2i:
		return false
	if baseImage.get_size() != imageSize:
		baseImage.resize(imageSize.x, imageSize.y)
	# The Y flip is a PAGE-space operation, so it uses the point rect, not pixels.
	var image = _image.new(Vector2i(imagePosition.x, _pageSize.y-imagePosition.y-(drawSize.y)), baseImage.get_size(), baseImage.get_data(), baseImage.get_format(), drawSize)
	_pages[pageNum-1].images.append(image)
	return true

func newFont(fontName : String, fontPath : String) -> bool:
	var font = _font.new(fontName, fontPath)
	_fonts.append(font)
	_fontList.append(fontName)
	return true

func export(path : String) -> bool:
	totalImages = 0
	totalPages = len(_pages)
	var images = []
	for p in _pages:
		for i in p.images:
			images.append(i)
	
	if path == null or path == "" or len(path) < 5 or path.substr(len(path)-4) != ".pdf":
		return false
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	
	_xref = []
	var content = "%PDF-1.6\n"
	
	_xref.append(len(content))				# save byte offset of next object to xref table
	# LOCAL PATCH (Five Parsecs, Aug 9 2026) — was `_addInfo("Test", "Nolan")`.
	#
	# Upstream ignored newPDF()/setTitle()/setCreator() entirely and hardcoded the
	# addon author's own test values into the /Info dictionary, so EVERY exported
	# document reported Title "Test" and Creator "Nolan". That is not cosmetic:
	# /Info /Title is what a PDF reader shows in its title bar, what Chrome shows in
	# the browser TAB, and what a file manager or archive tool indexes. A player
	# mailing their crew sheet was mailing a file called "Test" by a stranger.
	# Verified on a fresh export before the fix, by reading /Info back with PyPDF2.
	content += _addInfo(_title, _creator)		# add new info object
	
	# Add default font
	_xref.append(len(content))
	content += str(len(_xref)) + " 0 obj\n<<\n"
	content += "/Type /Font\n/Subtype /Type1\n/BaseFont /Helvetica"
	content += "\n>>\nendobj\n"
	file.store_string(content)
	var fontOffset = len(content)
	content = ""
	for i in _fonts:
		_xref.append(len(content) + fontOffset)
		fontOffset += _addFont(i, len(content) + fontOffset, file)					# add font object
	
	_xref.append(len(content) + fontOffset)
	content += _addPageTree()			# add page tree
	
	while(len(_pages) > 0):
		_xref.append(len(content) + fontOffset)
		content += _addPage()				# add new page
		_xref.append(len(content) + fontOffset)
		content += _addPageContent()			# add content for new page
	
	# add pages tree and catalog last
	_xref.append(len(content) + fontOffset)
	content += _addCatalog()
	var root = len(_xref)
	
	# add image dictionaries
	file.store_string(content)
	var offset = len(content) + fontOffset
	content = ""
	offset += _addImageDictionary(offset, images, file)
	
	# adds xref and footer information
	_xrefOffset = len(content)+offset
	content += _buildXref()
	content += _buildTrailer(root)
	
	file.store_string(content)
	file.close()
	
	return true

func _addFont(font, contentLength, file : FileAccess):
	var fontWidths = "["
	var f = FontFile.new()
	f.load_dynamic_font(font.fontPath)
	for i in range(256):
		fontWidths += str(f.get_string_size(char(i), 0, -1, 1000).x) + " "
	fontWidths += "]"
	
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Font\n/Subtype /TrueType\n/BaseFont /" + font.fontName + "\n"
	ret += "/FontDescriptor " + str(len(_xref)+1) + " 0 R\n"
	ret += "/FirstChar 0\n/LastChar 255\n"
	ret += "/Widths " + fontWidths
	ret += "\n>>\nendobj\n"
	
	_xref.append(len(ret) + contentLength)
	ret += str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /FontDescriptor\n/FontName /" + font.fontName + "\n"
	ret += "/FontFile2 " + str(len(_xref)+1) + " 0 R\n"
	ret += "/Flags 6\n/FontBBox [-1000 -1000 1000 1000]\n/MissingWidth 500"
	ret += "\n>>\nendobj\n"
	
	_xref.append(len(ret) + contentLength)
	ret += str(len(_xref)) + " 0 obj\n<<\n"
	var fontStream = FileAccess.get_file_as_bytes(font.fontPath)
	var offset = len(fontStream)
	ret += "/Length " + str(offset) + "\n" + "/Length1 " + str(offset)
	ret += "\n>>\nstream\n"
	file.store_string(ret)
	offset += len(ret)
	for b in fontStream:
		file.store_8(b)
	ret = "\nendstream\nendobj\n"
	file.store_string(ret)
	offset += len(ret)
	
	return offset

func _addInfo(Title=null, Creator=null):
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	if Title:
		ret += "/Title (" + escapePdfText(str(Title)) + ")\n"
	if Creator:
		ret += "/Creator (" + escapePdfText(str(Creator)) + ")\n"
	# LOCAL PATCH (Five Parsecs, Aug 9 2026) — /Producer and /CreationDate.
	#
	# Upstream wrote neither. /CreationDate is what a file manager sorts on and
	# what an archive records; without it an exported sheet has no date of its own
	# beyond the filesystem's, which does not survive being mailed or synced.
	# Format is PDF 1.7 §7.9.4: D:YYYYMMDDHHmmSSOHH'mm', O being the UTC offset
	# sign. Built from the LOCAL clock with the matching local offset, so the two
	# halves cannot disagree.
	ret += "/Producer (GodotPDF)\n"
	var t = Time.get_datetime_dict_from_system()
	var bias = Time.get_time_zone_from_system()
	var offset_min = int(bias.get("bias", 0))
	var sign = "+" if offset_min >= 0 else "-"
	offset_min = abs(offset_min)
	ret += "/CreationDate (D:%04d%02d%02d%02d%02d%02d%s%02d'%02d')\n" % [
		t.year, t.month, t.day, t.hour, t.minute, t.second,
		sign, offset_min / 60, offset_min % 60]
	ret += ">>\nendobj\n"
	return ret

func _buildXref():
	var ret = "xref\n0 "
	ret += str(len(_xref)+1) + "\n"
	ret += "0000000000 65535 f \n"
	for i in _xref:
		ret += _paddedOffset(i) + " 00000 n \n"
	return ret

func _paddedOffset(offset):
	var ret = ""
	for i in range(10-len(str(offset))):
		ret += "0"
	ret += str(offset)
	return ret

func _buildTrailer(root):
	var ret = "trailer\n<<\n"
	ret += "/Size " + str(len(_xref)+1) + "\n"
	ret += "/Root " + str(root) + " 0 R\n"
	ret += "/Info 1 0 R\n"
	ret += ">>\nstartxref\n"
	ret += str(_xrefOffset) + "\n%%EOF"
	return ret

func _addCatalog():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Catalog\n"
	ret += "/Pages " + str(3 + ((len(_fontList)-1)*3)) + " 0 R\n"
	ret += ">>\nendobj\n"
	return ret

func _addPageTree():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Pages\n"
	# LOCAL PATCH (Five Parsecs, Aug 9 2026) — /MediaBox is a REQUIRED page
	# attribute (PDF 1.7 spec, Table 30); upstream emitted none at all, on the
	# page or the tree, so every exported file was technically malformed and
	# viewers were guessing the page size. Declared here on the Pages node
	# because MediaBox is inheritable, so one entry covers every page.
	ret += "/MediaBox [0 0 " + str(_pageSize.x) + " " + str(_pageSize.y) + "]\n"
	ret += "/Count " + str(len(_pages)) + "\n"
	ret += "/Kids ["
	var pageNum = -1
	for i in _pages:
		pageNum += 1
		ret += str(4 + ((len(_fontList)-1)*3) + (pageNum*2)) + " 0 R "
	ret += "]\n"
	ret += ">>\nendobj\n"
	return ret

var totalImages = 0
var totalPages = 0
func _addPage():
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Type /Page\n"
	ret += "/Parent " + str(3 + ((len(_fontList)-1)*3)) + " 0 R\n"
	ret += "/Resources <</Font <</F0 2 0 R"
	for f in range(len(_fonts)):
		ret += " /F" + str(f+1) + " " + str((f*3)+3) + " 0 R"
	ret += ">> /XObject <<"
	var imageNum = 0
	for i in _pages[0].images:
		imageNum += 1
		ret += "/Im" + str(imageNum) + " " + str(totalImages + ((len(_fontList)-1)*3) + (totalPages*2) + 5) + " 0 R "
		totalImages += 1
	ret += ">>>>\n"
	ret += "/Contents [" + str(len(_xref)+1) + " 0 R]\n"
	ret += ">>\nendobj\n"
	return ret

func _addImageDictionary(contentLength, images, file : FileAccess):
	var offset = 0
	for i in images:
		_xref.append(contentLength + offset)
		var ret = str(len(_xref)) + " 0 obj\n<<\n"
		ret += "/Type /XObject\n/Subtype /Image\n"
		ret += "/Width " + str(i.size.x) + "\n"
		ret += "/Height " + str(i.size.y) + "\n"
		ret += "/ColorSpace /DeviceRGB\n/BitsPerComponent 8\n"

		# Add dataStreamAsBytes
		#
		# LOCAL PATCH (Five Parsecs, Aug 9 2026) — bulk writes instead of per-byte.
		# Upstream looped `file.store_8()` once per colour channel: 749,088 calls for
		# the 612x408 stream this used to produce (612*408*3, and the file was exactly
		# 749,922 bytes, so the stream IS the file). MEASURED at over 4 minutes on a
		# TB361FU with the UI frozen; after the patch, the same export finished in
		# under 2.4 s on the same device. The byte values written are identical; only
		# the number of calls changes. Re-apply this if the addon is ever updated.
		#
		# Why per-byte was catastrophic on Android specifically but merely slow on
		# desktop: the Android target writes to a SAF `content://` stream, so each
		# store_8 crosses the JNI bridge. (VERIFIED: the call count and the timings.
		# INFERRED: that JNI crossing is what makes the same loop ~100x worse here.)
		#
		# ⚠ Do NOT size this stream from the sheet's own resolution — newImage()
		# resamples to `imageSize` BEFORE the writer ever sees the data, so the
		# number of bytes here is set by the caller, not by the source art.
		var rgb: PackedByteArray
		match(i.format):
			Image.FORMAT_RGBA8:
				# Drop alpha into a contiguous RGB buffer. Fully transparent pixels
				# still flatten to white, as upstream did.
				var px_count: int = len(i.dataStream) / 4
				rgb = PackedByteArray()
				rgb.resize(px_count * 3)
				for j in range(px_count):
					var s: int = j * 4
					var d: int = j * 3
					if i.dataStream[s + 3] == 0:
						rgb[d] = 255
						rgb[d + 1] = 255
						rgb[d + 2] = 255
					else:
						rgb[d] = i.dataStream[s]
						rgb[d + 1] = i.dataStream[s + 1]
						rgb[d + 2] = i.dataStream[s + 2]
			Image.FORMAT_RGB8:
				# Already contiguous RGB — no per-pixel work at all. This is the
				# path our exporter takes (see PdfExportRouter).
				rgb = i.dataStream

		# LOCAL PATCH (Five Parsecs, Aug 9 2026) — /FlateDecode.
		#
		# Upstream wrote the pixel stream uncompressed. That was survivable only
		# because it also downsampled every image to 72 DPI; now that we keep the
		# sheet's native pixels, the raw stream is 15.3 MB (2764*1843*3) and an
		# uncompressed PDF is not a reasonable thing to hand a user.
		#
		# PDF's /FlateDecode is zlib (RFC1950), NOT raw deflate (RFC1951) — and
		# Godot's COMPRESSION_DEFLATE is the zlib-wrapped form, so it can be
		# handed over directly with no reframing. VERIFIED, not assumed: the
		# output starts 0x78 0x9C and Python's strict zlib.decompress() reads it.
		# COMPRESSION_GZIP would NOT work here (0x1F 0x8B, wrong container).
		#
		# Lossless, so the printed sheet is bit-identical to the render.
		var stream_bytes: PackedByteArray = rgb.compress(FileAccess.COMPRESSION_DEFLATE)
		ret += "/Filter /FlateDecode\n"
		ret += "/Length " + str(stream_bytes.size()) + "\n>>\n"
		ret += "stream\n"
		file.store_string(ret)
		offset += len(ret)
		file.store_buffer(stream_bytes)
		offset += stream_bytes.size()

		ret = "\nendstream\nendobj\n"
		file.store_string(ret)
		offset += len(ret)
	return offset

## Zero-caller since the /FlateDecode patch — the stream length is now the
## COMPRESSED size, which only the writer knows. Kept (not deleted) because this
## is vendored upstream API and removing it would complicate re-applying our
## patches against a newer release.
func _getImageLength(dataSize, format) -> String:
	match(format):
		Image.FORMAT_RGBA8:
			return str((dataSize/4)*3)
		Image.FORMAT_RGB8:
			return str(dataSize)

	return str(dataSize)

func _addPageContent():
	var textContent = _pages[0].text
	var boxContent = _pages[0].boxes
	var imageContent = _pages[0].images
	var contentStream = ""
	_pages.remove_at(0)
	if len(imageContent) > 0:	# Draw images
		var imageNum = 0
		for i in imageContent:
			imageNum += 1
			contentStream += "q\n"
			# LOCAL PATCH: paint at the POINT rect (i.drawSize), not the pixel
			# size. `Do` always stretches the image to this matrix, so more
			# pixels in the same rect simply means higher DPI.
			contentStream += str(i.drawSize.x) + " 0 0 " + str(i.drawSize.y) + " " + str(i.position.x) + " " + str(i.position.y) + " cm\n"
			contentStream += "/Im" + str(imageNum) + " Do\n"
			contentStream += "Q\n"
	if len(boxContent) > 0:		# Draw boxes
		for x in range(len(boxContent)):
			var i = boxContent[x]
			var rect = str(i.position.x) + " " + str(i.position.y) + " " + str(i.size.x) + " " + str(i.size.y) + " re"
			if i.fill != null:
				contentStream += rect + "\n"
				contentStream += str(i.fill.r) + " " + str(i.fill.g) + " " + str(i.fill.b) + " rg\n"
				contentStream += "f"
				if i.border != null:
					contentStream += "\n"
			if i.border != null:
				contentStream += rect + "\n"
				contentStream += str(i.border.r) + " " + str(i.border.g) + " " + str(i.border.b) + " RG\n"
				contentStream += str(i.borderWidth) + " w\n"
				contentStream += "S"
			if x < len(boxContent)-1:
				contentStream += "\n"
		if len(textContent) > 0:
			contentStream += "\n0.0 0.0 0.0 rg\n"
	if len(textContent) > 0:	# Draw text
		contentStream += "BT\n"
		var lastPos = null
		var lastSize = 0
		# LOCAL PATCH (Five Parsecs, Aug 9 2026) — track the render mode so `Tr` is
		# emitted only when it CHANGES. Graphics state persists inside a BT/ET block,
		# so re-stating it per label would be ~180 redundant operators on our sheet.
		var lastMode = 0
		for i in textContent:
			contentStream += "/F" + str(_fontList.find(i.font)) + " " + str(i.fontSize) + " Tf\n"
			if i.renderMode != lastMode:
				contentStream += str(i.renderMode) + " Tr\n"
				lastMode = i.renderMode
			if lastPos:
				contentStream += str(i.position.x - lastPos.x) + " " + str((i.position.y - i.fontSize) - (lastPos.y - lastSize)) + " Td\n"
			else:
				contentStream += str(i.position.x) + " " + str(i.position.y - i.fontSize) + " Td\n"
			# LOCAL PATCH — escape. Upstream concatenated raw user text, so any
			# `(`, `)` or `\` in a crew or ship name produced a corrupt file.
			contentStream += "(" + escapePdfText(i.text) + ") Tj\n"
			lastPos = i.position
			lastSize = i.fontSize
		contentStream += "ET"
	var ret = str(len(_xref)) + " 0 obj\n<<\n"
	ret += "/Length " + str(len(contentStream)) + "\n"
	ret += ">>\nstream\n"
	ret += contentStream + "\n"
	ret += "endstream\nendobj\n"
	return ret
