package openfl._internal.renderer.context3D;

import openfl._internal.backend.gl.GLBuffer;
import openfl._internal.backend.gl.GLFramebuffer;
import openfl._internal.backend.gl.GLRenderbuffer;
import openfl._internal.backend.gl.GLTexture;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.Context3DBlendFactor;
import openfl.display3D.Context3DCompareMode;
import openfl.display3D.Context3DStencilAction;
import openfl.display3D.Context3DTriangleFace;
import openfl.display3D.Program3D;
import openfl.display.Shader;
import openfl.geom.Rectangle;
#if lime
import lime.graphics.opengl.GL;
#end

@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DState
{
	public var backBufferEnableDepthAndStencil:Bool;
	public var blendDestinationAlphaFactor:Context3DBlendFactor;
	public var blendSourceAlphaFactor:Context3DBlendFactor;
	public var blendDestinationRGBFactor:Context3DBlendFactor;
	public var blendSourceRGBFactor:Context3DBlendFactor;
	public var colorMaskRed:Bool;
	public var colorMaskGreen:Bool;
	public var colorMaskBlue:Bool;
	public var colorMaskAlpha:Bool;
	public var culling:Context3DTriangleFace;
	public var depthCompareMode:Context3DCompareMode;
	public var depthMask:Bool;
	// public var fillMode:Context3DFillMode;
	public var program:Program3D;
	// program constants?
	public var renderToTexture:TextureBase;
	public var renderToTextureAntiAlias:Int;
	public var renderToTextureDepthStencil:Bool;
	public var renderToTextureSurfaceSelector:Int;
	public var samplerStates:Array<SamplerState>;
	public var scissorEnabled:Bool;
	public var scissorRectangle:Rectangle;
	public var stencilCompareMode:Context3DCompareMode;
	public var stencilDepthFail:Context3DStencilAction;
	public var stencilFail:Context3DStencilAction;
	public var stencilPass:Context3DStencilAction;
	public var stencilReadMask:UInt;
	public var stencilReferenceValue:UInt;
	public var stencilTriangleFace:Context3DTriangleFace;
	public var stencilWriteMask:UInt;
	public var textures:Array<TextureBase>;
	// vertex buffer at?
	public var shader:Shader; // TODO: Merge shader/program3d
	public var stateDirty:Bool = false;

	private var __currentGLArrayBuffer:GLBuffer;
	private var __currentGLElementArrayBuffer:GLBuffer;
	private var __currentGLFramebuffer:GLFramebuffer;
	private var __currentGLTexture2D:GLTexture;
	private var __currentGLTextureCubeMap:GLTexture;
	private var __enableGLBlend:Bool;
	private var __enableGLCullFace:Bool;
	private var __enableGLDepthTest:Bool;
	private var __enableGLScissorTest:Bool;
	private var __enableGLStencilTest:Bool;
	private var __frontFaceGLCCW:Bool;
	private var __glBlendEquation:Int;
	private var __primaryGLFramebuffer:GLFramebuffer;
	private var __rttDepthGLRenderbuffer:GLRenderbuffer;
	private var __rttGLFramebuffer:GLFramebuffer;
	private var __rttGLRenderbuffer:GLRenderbuffer;
	private var __rttStencilGLRenderbuffer:GLRenderbuffer;

	public function new()
	{
		backBufferEnableDepthAndStencil = false;
		blendDestinationAlphaFactor = ZERO;
		blendSourceAlphaFactor = ONE;
		blendDestinationRGBFactor = ZERO;
		blendSourceRGBFactor = ONE;
		colorMaskRed = true;
		colorMaskGreen = true;
		colorMaskBlue = true;
		colorMaskAlpha = true;
		culling = NONE;
		depthCompareMode = LESS;
		depthMask = true;
		samplerStates = new Array();
		scissorRectangle = new Rectangle();
		stencilCompareMode = ALWAYS;
		stencilDepthFail = KEEP;
		stencilFail = KEEP;
		stencilPass = KEEP;
		stencilReadMask = 0xFF;
		stencilReferenceValue = 0;
		stencilTriangleFace = FRONT_AND_BACK;
		stencilWriteMask = 0xFF;
		textures = new Array();
		__frontFaceGLCCW = true;

		#if lime
		__glBlendEquation = GL.FUNC_ADD;
		#end
	}

	public function clone() : Context3DState
	{
		var clone = new Context3DState();
		clone.backBufferEnableDepthAndStencil = backBufferEnableDepthAndStencil;
		clone.blendDestinationAlphaFactor = blendDestinationAlphaFactor;
		clone.blendSourceAlphaFactor = blendSourceAlphaFactor;
		clone.blendDestinationRGBFactor = blendDestinationRGBFactor;
		clone.blendSourceRGBFactor = blendSourceRGBFactor;
		clone.colorMaskRed = colorMaskRed;
		clone.colorMaskGreen = colorMaskGreen;
		clone.colorMaskBlue = colorMaskBlue;
		clone.colorMaskAlpha = colorMaskAlpha;
		clone.culling = culling;
		clone.depthCompareMode = depthCompareMode;
		clone.depthMask = depthMask;
		clone.program = program;
		clone.renderToTexture = renderToTexture;
		clone.renderToTextureAntiAlias = renderToTextureAntiAlias;
		clone.renderToTextureDepthStencil = renderToTextureDepthStencil;
		clone.renderToTextureSurfaceSelector = renderToTextureSurfaceSelector;
		clone.samplerStates = samplerStates;
		clone.scissorEnabled = scissorEnabled;
		clone.scissorRectangle = scissorRectangle;
		clone.stencilCompareMode = stencilCompareMode;
		clone.stencilDepthFail = stencilDepthFail;
		clone.stencilFail = stencilFail;
		clone.stencilPass = stencilPass;
		clone.stencilReadMask = stencilReadMask;
		clone.stencilReferenceValue = stencilReferenceValue;
		clone.stencilTriangleFace = stencilTriangleFace;
		clone.stencilWriteMask = stencilWriteMask;
		clone.textures = textures;
		clone.shader = shader;
		clone.__frontFaceGLCCW = __frontFaceGLCCW;
		#if lime
		clone.__glBlendEquation = __glBlendEquation;
		#end
		return clone;
	}

	public function fromState( src:Context3DState)
	{
		backBufferEnableDepthAndStencil = src.backBufferEnableDepthAndStencil;
		blendDestinationAlphaFactor = src.blendDestinationAlphaFactor;
		blendSourceAlphaFactor = src.blendSourceAlphaFactor;
		blendDestinationRGBFactor = src.blendDestinationRGBFactor;
		blendSourceRGBFactor = src.blendSourceRGBFactor;
		colorMaskRed = src.colorMaskRed;
		colorMaskGreen = src.colorMaskGreen;
		colorMaskBlue = src.colorMaskBlue;
		colorMaskAlpha = src.colorMaskAlpha;
		culling = src.culling;
		depthCompareMode = src.depthCompareMode;
		depthMask = src.depthMask;
		program = src.program;
		renderToTexture = src.renderToTexture;
		renderToTextureAntiAlias = src.renderToTextureAntiAlias;
		renderToTextureDepthStencil = src.renderToTextureDepthStencil;
		renderToTextureSurfaceSelector = src.renderToTextureSurfaceSelector;
		samplerStates = src.samplerStates;
		scissorEnabled = src.scissorEnabled;
		scissorRectangle = src.scissorRectangle;
		stencilCompareMode = src.stencilCompareMode;
		stencilDepthFail = src.stencilDepthFail;
		stencilFail = src.stencilFail;
		stencilPass = src.stencilPass;
		stencilReadMask = src.stencilReadMask;
		stencilReferenceValue = src.stencilReferenceValue;
		stencilTriangleFace = src.stencilTriangleFace;
		stencilWriteMask = src.stencilWriteMask;
		textures = src.textures;
		shader = src.shader;
		__frontFaceGLCCW = src.__frontFaceGLCCW;
		#if lime
		__glBlendEquation = src.__glBlendEquation;
		#end
	}
}
