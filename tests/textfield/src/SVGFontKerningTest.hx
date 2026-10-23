package;

#if svg
import openfl.text.SVGFont;
import openfl.text.TextField;
import openfl.text.TextFormat;
import utest.Assert;
import utest.Test;

class SVGFontKerningTest extends Test
{
	public function setup()
	{
		SVGFont.registerFont(font('<hkern u1="A" u2="V" k="80" />'
			+ '<hkern u1="A" u2="V" k="10" />'
			+ '<hkern u1="T" u2="o,e" k="120" />'
			+ '<hkern u1="o,e" u2="T" k="40" />'
			+ '<hkern g1="V" g2="A" k="60" />'
			+ '<hkern u1="A" u2="&amp;" k="-25" />'), "Kerned");
	}

	public function test_getKerning()
	{
		Assert.equals(80, SVGFont.getKerning("A", "V", "Kerned"));
		Assert.equals(60, SVGFont.getKerning("V", "A", "Kerned"));
		Assert.equals(120, SVGFont.getKerning("T", "o", "Kerned"));
		Assert.equals(120, SVGFont.getKerning("T", "e", "Kerned"));
		Assert.equals(40, SVGFont.getKerning("o", "T", "Kerned"));
		Assert.equals(40, SVGFont.getKerning("e", "T", "Kerned"));
		Assert.equals(-25, SVGFont.getKerning("A", "&", "Kerned"));
		Assert.equals(0, SVGFont.getKerning("A", "A", "Kerned"));
		Assert.equals(0, SVGFont.getKerning("A", "V", "Unknown"));
	}

	public function test_registerFont_replacesPairs()
	{
		SVGFont.registerFont(font(""), "Kerned");

		Assert.equals(0, SVGFont.getKerning("A", "V", "Kerned"));
	}

	public function test_measureInk()
	{
		Assert.equals(1120, SVGFont.measureInk("AV", "Kerned", 1000).width);
		Assert.equals(1200, SVGFont.measureInk("AA", "Kerned", 1000).width);
		Assert.equals(1140, SVGFont.measureInk("VA", "Kerned", 1000).width);
		Assert.equals(56, SVGFont.measureInk("AV", "Kerned", 50).width);
	}

	public function test_renderSVGGroup()
	{
		Assert.isTrue(SVGFont.renderSVGGroup("AV", "Kerned", 0, 0, 1000).indexOf("M520 700") >= 0);
	}

	public function test_layoutPositions()
	{
		var format = new TextFormat("Kerned", 50);
		format.useSVGFont = true;
		var textField = new TextField();
		textField.defaultTextFormat = format;
		textField.text = "AVA";
		@:privateAccess textField.__updateLayout();
		var group = @:privateAccess textField.__textEngine.layoutGroups[0];

		Assert.equals("26,27,30", group.positions.join(","));
		Assert.equals(83, group.width);
	}

	static function font(kerning:String):String
	{
		return '<?xml version="1.0" standalone="no"?><svg xmlns="http://www.w3.org/2000/svg" version="1.1"><defs><font id="Kerned" horiz-adv-x="500">'
			+ '<font-face font-family="Kerned" units-per-em="1000" ascent="800" descent="-200" />'
			+ '<missing-glyph horiz-adv-x="500" d="M0 0l100 0l0 100z" />'
			+ '<glyph glyph-name="A" unicode="A" horiz-adv-x="600" d="M0 0l600 0l-300 700z" />'
			+ '<glyph glyph-name="V" unicode="V" horiz-adv-x="600" d="M0 700l600 0l-300 -700z" />'
			+ '<glyph glyph-name="T" unicode="T" horiz-adv-x="600" d="M0 600l600 0l0 100l-600 0z" />'
			+ '<glyph glyph-name="o" unicode="o" horiz-adv-x="500" d="M0 0l500 0l0 500l-500 0z" />'
			+ '<glyph glyph-name="e" unicode="e" horiz-adv-x="500" d="M0 0l500 0l0 500l-500 0z" />'
			+ '<glyph glyph-name="ampersand" unicode="&amp;" horiz-adv-x="700" d="M0 0l700 0l0 700l-700 0z" />'
			+ kerning
			+ '</font></defs></svg>';
	}
}
#end
