import {Params,ParamsMeta} from './Params.js'
import Camera_t from './PopEngineCommon/Camera.js'
import Pop from './PopEngineCommon/PopEngine.js'
import {CreateBlitQuadGeometry} from './PopEngineCommon/CommonGeometry.js'
import {MatrixInverse4x4} from './PopEngineCommon/Math.js'
import {LoadFileAsImageAsync,LoadFileAsStringAsync} from './PopEngineCommon/FileSystem.js'


const Earth = Pop.GetExeArguments().Earth;
const EnableImages = Pop.GetExeArguments().EnableImages!==false;
//const EnableImages = false;

const HeightmapShaderVert = 'Quad.vert.glsl';
const HeightmapShaderFrag = 'HeightMap.frag.glsl';
const HeightmapShaderMacros = {};

//const ColourFilename = 'Earth_ColourMay_4096.jpg';
//const ColourFilename = 'lroc_color_poles_4k.jpg';
//const ColourFilename = 'Moon_Colour_1024x512.jpg';
const ColourFilename = 'Moon_Colour_2048x1024.jpg';

//const HeightmapFilename = 'Earth_Heightmap_4096.png';
//const HeightmapFilename = 'ldem_16_uint.jpg';
//const HeightmapFilename = 'Moon_Depth_1024x512.jpg';
const HeightmapFilename = 'Moon_Depth_2048x1024.jpg';




const RandomNumberCache = [];

function GetRandomNumberArray(Count)
{
	if ( RandomNumberCache.length < Count )
		Pop.Debug("calculating random numbers x"+Count);
	while ( RandomNumberCache.length < Count )
	{
		RandomNumberCache.push( Math.random() );
	}
	return RandomNumberCache;
}


function CreateRandomSphereImage(Width,Height)
{
	let Channels = 4;
	let Format = 'Float4';
	
	const TimerStart = Pop.GetTimeNowMs();
	
	let Pixels = new Float32Array( Width * Height * Channels );
	const Rands = GetRandomNumberArray(Pixels.length*Channels);
	for ( let i=0;	i<Pixels.length;	i+=Channels )
	{
		let xyz = Rands.slice( i*Channels, (i*Channels)+Channels );
		let w = xyz[3];
		xyz = Math.Subtract3( xyz, [0.5,0.5,0.5] );
		xyz = Math.Normalise3( xyz );
		xyz = Math.Add3( xyz, [1,1,1] );
		xyz = Math.Multiply3( xyz, [0.5,0.5,0.5] );
		
		Pixels[i+0] = xyz[0];
		Pixels[i+1] = xyz[1];
		Pixels[i+2] = xyz[2];
		Pixels[i+3] = w;
	}
	
	Pop.Debug("CreateRandomSphereImage() took", Pop.GetTimeNowMs() - TimerStart);
	
	let Texture = new Pop.Image();
	Texture.WritePixels( Width, Height, Pixels, Format );
	return Texture;
}


Pop.CreateColourTexture = function(Colour4)
{
	let NewTexture = new Pop.Image();
	if ( Array.isArray(Colour4) )
		Colour4 = new Float32Array(Colour4);
	NewTexture.WritePixels( 1, 1, Colour4, 'Float4' );
	return NewTexture;
}

	
function Render(RenderTarget,Camera)
{
	const RenderContext = RenderTarget.GetRenderContext();


	let ProjectionViewport = RenderTarget.GetRenderTargetRect();
	ProjectionViewport[0] = 0;
	ProjectionViewport[1] = 0; 
	const Quad = GetAsset('Quad',RenderContext);
	const Shader = GetAsset(RenderHeightmapShader,RenderContext);
	const WorldToCameraMatrix = Camera.GetWorldToCameraMatrix();
	const CameraProjectionMatrix = Camera.GetProjectionMatrix( ProjectionViewport );
	const ScreenToCameraTransform = Math.MatrixInverse4x4( CameraProjectionMatrix );
	const CameraToWorldTransform = Math.MatrixInverse4x4( WorldToCameraMatrix );
	const LocalToWorldTransform = Camera.GetLocalToWorldFrustumTransformMatrix();
	//const LocalToWorldTransform = Math.CreateIdentityMatrix();
	const WorldToLocalTransform = Math.MatrixInverse4x4(LocalToWorldTransform);
	//Pop.Debug("Camera frustum LocalToWorldTransform",LocalToWorldTransform);
	//Pop.Debug("Camera frustum WorldToLocalTransform",WorldToLocalTransform);
	
	//	these should be GetAsset
	const Colour = MoonColourTexture;
	const Heightmap = MoonDepthTexture;
	
	
	const SetUniforms = function(Shader)
	{
		Shader.SetUniform('VertexRect',[0,0,1,1]);
		Shader.SetUniform('ScreenToCameraTransform',ScreenToCameraTransform);
		Shader.SetUniform('CameraToWorldTransform',CameraToWorldTransform);
		Shader.SetUniform('LocalToWorldTransform',LocalToWorldTransform);
		Shader.SetUniform('WorldToLocalTransform',WorldToLocalTransform);
		Shader.SetUniform('HeightmapTexture',Heightmap);
		Shader.SetUniform('ColourTexture',Colour);
		
		function SetUniform(Key)
		{
			Shader.SetUniform( Key, Params[Key] );
		}
		Object.keys(Params).forEach(SetUniform);
	}
	RenderTarget.SetBlendModeAlpha();
	RenderTarget.DrawGeometry( Quad, Shader, SetUniforms );

}


let QuadGeometry;
let RaymarchShader;
let MoonColourTexture = Pop.CreateColourTexture([0.1,0.8,0.8,1]);
let MoonDepthTexture = Pop.CreateColourTexture([0,0,0,1]);


async function LoadAssets(RenderContext)
{
	if ( !QuadGeometry )
	{
		const BlitQuad = CreateBlitQuadGeometry();
		QuadGeometry = await RenderContext.CreateGeometry( BlitQuad );
	}
	
	if ( !RaymarchShader )
	{
		const VertSource = await LoadFileAsStringAsync( HeightmapShaderVert );
		const FragSource = await LoadFileAsStringAsync( HeightmapShaderFrag );
		RaymarchShader = await RenderContext.CreateShader( VertSource, FragSource, HeightmapShaderMacros );
	}
	/*
	if ( !MoonColourTexture )
	{
		MoonColourTexture = await LoadFileAsImageAsync(ColourFilename);
		MoonColourTexture.SetLinearFilter(true);
	}
	
	if ( !MoonDepthTexture )
	{
		MoonDepthTexture = await LoadFileAsImageAsync(HeightmapFilename);
		MoonDepthTexture.SetLinearFilter(true);
	}
	 */
}

function GetRenderCommands(Camera,ScreenRect)
{
	const Commands = [];
	
	const Clear = ['SetRenderTarget',null,[1,0,0]];
	Commands.push(Clear);
	
	
	let ProjectionViewport = ScreenRect;
	//ProjectionViewport[0] = 0;
	//ProjectionViewport[1] = 0; 

	const Quad = QuadGeometry;
	const Shader = RaymarchShader;
	const WorldToCameraMatrix = Camera.GetWorldToCameraMatrix();
	const CameraProjectionMatrix = Camera.GetProjectionMatrix( ProjectionViewport );
	const ScreenToCameraTransform = MatrixInverse4x4( CameraProjectionMatrix );
	const CameraToWorldTransform = MatrixInverse4x4( WorldToCameraMatrix );
	const LocalToWorldTransform = Camera.GetLocalToWorldFrustumTransformMatrix();
	//const LocalToWorldTransform = Math.CreateIdentityMatrix();
	const WorldToLocalTransform = MatrixInverse4x4(LocalToWorldTransform);
	//Pop.Debug("Camera frustum LocalToWorldTransform",LocalToWorldTransform);
	//Pop.Debug("Camera frustum WorldToLocalTransform",WorldToLocalTransform);
	
	//	these should be GetAsset
	const Colour = MoonColourTexture;
	const Heightmap = MoonDepthTexture;
	
	const Uniforms = {}
	Object.assign( Uniforms, Params );
	Uniforms.VertexRect = [0,0,1,1];
	Uniforms.ScreenToCameraTransform = ScreenToCameraTransform;
	Uniforms.CameraToWorldTransform = CameraToWorldTransform;
	Uniforms.LocalToWorldTransform = LocalToWorldTransform;
	Uniforms.WorldToLocalTransform = WorldToLocalTransform;
	Uniforms.HeightmapTexture = Heightmap;
	Uniforms.ColourTexture = Colour;

	const Draw = ['Draw',Quad,Shader,Uniforms];
	Commands.push(Draw);

	return Commands;
}


function InitCameraControls(Gui,Camera)
{
	function MoveCamera(x,y,Button,FirstDown)
	{
		//if ( Button == 0 )
		//	this.Camera.OnCameraPan( x, 0, y, FirstDown );
		if ( Button == 'Left' )
			Camera.OnCameraPanLocal( -x, y, 0, FirstDown );
		if ( Button == 'Right' )
			Camera.OnCameraPanLocal( x, y, 0, FirstDown );
		if ( Button == 'Middle' )
			Camera.OnCameraPanLocal( x, 0, y, FirstDown );
	}

	Gui.OnMouseDown = function(x,y,Button)
	{
		MoveCamera( x,y,Button,true );
	}

	Gui.OnMouseMove = function(x,y,Button)
	{
		MoveCamera( x,y,Button,false );
	}

	Gui.OnMouseScroll = function(x,y,Button,Delta)
	{
		let Fly = Delta[1] * 50;
		//Fly *= Params.ScrollFlySpeed;

		Camera.OnCameraPanLocal( 0, 0, 0, true );
		Camera.OnCameraPanLocal( 0, 0, Fly, false );
	}
}

async function ScreenRenderLoop()
{
	//	create window etc here
	let RenderView = new Pop.Gui.RenderView(null,'RenderCanvas');
	let RenderContext = new Pop.Opengl.Context(RenderView);
	let Camera = new Camera_t();
	Camera.LookAt = Params.MoonSphere.slice();
	Camera.Position = [0,1.6, Params.MoonSphere[2]+Params.MoonSphere[3]*3 ];

	InitCameraControls(RenderView,Camera);

	while ( RenderContext )
	{
		await LoadAssets(RenderContext);
		
		const ScreenRect = RenderView.GetScreenRect();
		const RenderCommands = GetRenderCommands( Camera, ScreenRect );
		
		await RenderContext.Render( RenderCommands );
	}
}

let ParamsWindow;
function InitParamsWindow()
{
	ParamsWindow = new Pop.Gui.Tree(null,'Params');
	
	function OnParamsChanged(NewParams)
	{
		Object.assign( Params, NewParams );
	}
	
	const Meta = ParamsMeta;
	for ( let Param in Params )
	{
		Meta[Param] = Meta[Param]||{};
		Meta[Param].Writable = true;
	}

	//	todo: this needs to be in gui code
	ParamsWindow.Element.meta = Meta;
	ParamsWindow.Element.onchange = OnParamsChanged
	
	

	ParamsWindow.SetValue(Params);
}
	

export default async function Boot()
{
	try
	{
		InitParamsWindow();
	}
	catch(e)
	{
		console.error(e);
	}
	
	//	bootup 2d screen
	const ScreenThread = ScreenRenderLoop();
	
	//	bootup XR
	
	//	wait for app to quit
	await ScreenThread;
}
