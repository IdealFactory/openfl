package;

#if svg
import openfl.text.SVGFont;
import utest.Assert;
import utest.Test;

class SVGFontFallbackTest extends Test
{
	public function setup()
	{
		SVGFont.fallbackFont = SVGFont.registerFont(font("Fallback", 2000, '<glyph glyph-name="Zhe" unicode="Ж" horiz-adv-x="1200" d="M0 0l1000 0l0 1400l-1000 0z" />'), "Fallback");
		SVGFont.registerFont(font("Main", 1000, '<glyph glyph-name="A" unicode="A" horiz-adv-x="600" d="M0 0l600 0l-300 700z" />'), "Main");
	}

	public function teardown()
	{
		SVGFont.fallbackFont = null;
	}

	public function test_drawsFallbackGlyphsInTheFontsUnits()
	{
		var drawn = SVGFont.renderSVGGroup("AЖ", "Main", 0, 0, 1000);

		Assert.isTrue(drawn.indexOf("M600 0l500 0l0 700l-500 0z") >= 0, drawn);
	}

	public function test_drawsFallbackGlyphsTheSizeTheyAreMeasured()
	{
		var ink = SVGFont.measureInk("AЖ", "Main", 1000);

		Assert.equals(1100, ink.width);
		Assert.equals(700, ink.height);
	}

	static function font(id:String, unitsPerEm:Int, glyphs:String):String
	{
		return '<?xml version="1.0" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" version="1.1"><defs><font id="' + id + '" horiz-adv-x="500">'
			+ '<font-face font-family="' + id + '" units-per-em="' + unitsPerEm + '" ascent="' + Std.int(unitsPerEm * 0.8) + '" descent="-' + Std.int(unitsPerEm * 0.2) + '" />'
			+ '<missing-glyph horiz-adv-x="500" d="M0 0l100 0l0 100z" />'
			+ glyphs
			+ '</font></defs></svg>';
	}
}
#end
