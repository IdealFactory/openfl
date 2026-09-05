package openfl.display;

#if !flash
/**
	The WebPEncoderOptions class defines a compression algorithm for the
	`openfl.display.BitmapData.encode()` method. Lossy WebP is encoded by the
	browser on the HTML5 target; `encode()` returns `null` where no WebP
	encoder is available.
**/
#if !openfl_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:final class WebPEncoderOptions
{
	/**
		A value between 1 and 100, where 1 means the lowest quality and 100 means the
		highest quality.
	**/
	public var quality:Int;

	/**
		Creates a WebPEncoderOptions object with the specified setting.

		@param	quality	The initial quality value.
	**/
	public function new(quality:Int = 80)
	{
		this.quality = quality;
	}
}
#end
