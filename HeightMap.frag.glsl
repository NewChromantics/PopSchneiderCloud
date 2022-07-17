precision highp float;

varying vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

uniform bool SquareStep;
uniform vec3 BackgroundColour;
#define MAX_STEPS	180
#define FAR_Z		1000.0

uniform float SunPositionX;
uniform float SunPositionY;
uniform float SunPositionZ;
const float SunRadius = 0.1;
#define SunPosition	vec3(SunPositionX,SunPositionY,SunPositionZ)
#define SunSphere	vec4(SunPosition,SunRadius)
const vec4 SunColour = vec4(1,1,0.3,1);

uniform float MoonPositionX;
uniform float MoonPositionY;
uniform float MoonPositionZ;
uniform float MoonRadius;
#define MoonSphere	vec4(MoonPositionX,MoonPositionY,MoonPositionZ,MoonRadius)
const vec4 MoonColour = vec4(0.9,0.9,0.9,1.0);


uniform sampler2D BlueNoiseTexture;
const float goldenRatio = 1.61803398875;
uniform bool ApplyBlueNoiseOffset;


struct TRay
{
	vec3 Pos;
	vec3 Dir;
};

vec3 ScreenToWorld(vec2 uv,float z)
{
	float x = mix( -1.0, 1.0, uv.x );
	float y = mix( 1.0, -1.0, uv.y );
	vec4 ScreenPos4 = vec4( x, y, z, 1.0 );
	vec4 CameraPos4 = ScreenToCameraTransform * ScreenPos4;
	vec4 WorldPos4 = CameraToWorldTransform * CameraPos4;
	vec3 WorldPos = WorldPos4.xyz / WorldPos4.w;
	
	return WorldPos;
}

void GetWorldRay(out vec3 RayPos,out vec3 RayDir)
{
	float Near = 0.01;
	float Far = FAR_Z;
	//	gr: in sdf editor this comes from vert
	vec3 WorldPosition = ScreenToWorld( uv, 0.01 );
	
	//	ray goes from camera
	//	to WorldPosition, which is the triangle's surface pos
	vec4 CameraWorldPos4 = CameraToWorldTransform * vec4(0,0,0,1);
	vec3 CameraWorldPos3 = CameraWorldPos4.xyz / CameraWorldPos4.w;
	RayPos = CameraWorldPos3;
	RayDir = WorldPosition - RayPos;
	RayDir = normalize(RayDir);
}

float Range(float Min,float Max,float Value)
{
	return (Value-Min) / (Max-Min);
}
float Range01(float Min,float Max,float Value)
{
	return clamp(Range(Min,Max,Value),0.0,1.0);
}

vec3 NormalToRedGreen(float Normal)
{
	if ( Normal < 0.5 )
	{
		Normal /= 0.5;
		return vec3( 1.0, Normal, 0.0 );
	}
	else
	{
		Normal -= 0.5;
		Normal /= 0.5;
		return vec3( 1.0-Normal, 1.0, 0.0 );
	}
}


void GetDistanceToSphere(vec3 Position,vec4 Sphere,vec4 SphereColour,inout float Distance,inout vec4 Colour)
{
	float DistanceToSphere = length(Sphere.xyz - Position) - Sphere.w;
	
	//	update current best
	if ( DistanceToSphere < Distance )
	{
		Distance = DistanceToSphere;
		Colour = SphereColour;
	}
}

//	need to change this to a distance
bool InsideCloudBounds(vec3 Position)
{
	return true;
}
#define CLOUD_EXTENT 1.0
const float cloudStart = 0.0;
const float cloudEnd = CLOUD_EXTENT;
const float iTime = 0.0;
#ifdef COLOUR_SCATTERING
const vec3 sigmaS = vec3(0.5, 1.0, 1.0);
#else
const vec3 sigmaS = vec3(1);
#endif
const vec3 sigmaA = vec3(0.0);

// Extinction coefficient.
const vec3 sigmaE = max(sigmaS + sigmaA, vec3(1e-6));

const float power = 200.0;
const float densityMultiplier = 0.5;

const float shapeSize = 0.4;
const float detailSize = 0.8;

const float shapeStrength = 0.6;
const float detailStrength = 0.35;

uniform float FixedStepDistance;
//#define FIXED_STEP_DISTANCE 0.010
#define FIXED_STEP_DISTANCE (FixedStepDistance/10000.0)


float HenyeyGreenstein(float g, float costh){
	return (1.0 / (4.0 * 3.1415))  * ((1.0 - g * g) / pow(1.0 + g*g - 2.0*g*costh, 1.5));
}

float Power = 200.0;


float saturate(float x){
	return clamp(x, 0.0, 1.0);
}

//	change this to Range() and lerp/mix()!
float remap(float x, float low1, float high1, float low2, float high2){
	return low2 + (x - low1) * (high2 - low2) / (high1 - low1);
}

float modulo(float m, float n){
  return mod(mod(m, n) + n, n);
}

float circularOut(float t)
{
	return sqrt((2.0 - t) * t);
}

float getPerlinWorleyNoise(vec3 pos)
{
	/*
	// The cloud shape texture is an atlas of 6*6 tiles (36).
	// Each tile is 32*32 with a 1 pixel wide boundary.
	// Per tile:		32 + 2 = 34.
	// Atlas width:	6 * 34 = 204.
	// The rest of the texture is black.
	// The 3D texture the atlas represents has dimensions 32 * 32 * 36.
	// The green channel is the data of the red channel shifted by one tile.
	// (tex.g is the data one level above tex.r).
	// To get the necessary data only requires a single texture fetch.
	const float dataWidth = 204.0;
	const float tileRows = 6.0;
	const vec3 atlasDimensions = vec3(32.0, 32.0, 36.0);

	// Change from Y being height to Z being height.
	vec3 p = pos.xzy;

	// Pixel coordinates of point in the 3D data.
	vec3 coord = vec3(mod(p, atlasDimensions));
	float f = fract(coord.z);
	float level = floor(coord.z);
	float tileY = floor(level/tileRows);
	float tileX = level - tileY * tileRows;

	// The data coordinates are offset by the x and y tile, the two boundary cells
	// between each tile pair and the initial boundary cell on the first row/column.
	vec2 offset = atlasDimensions.x * vec2(tileX, tileY) + 2.0 * vec2(tileX, tileY) + 1.0;
	vec2 pixel = coord.xy + offset;
	vec2 data = texture(iChannel0, mod(pixel, dataWidth)/iChannelResolution[0].xy).xy;
	return mix(data.x, data.y, f);
	 */
	return 0.3;
}

float getCloudMap(vec3 p)
{
	vec2 uv = 0.5 + 0.5 * (p.xz/(1.8 * CLOUD_EXTENT));
	//return texture(iChannel2, uv).x;

	
	//	this is generated in https://www.shadertoy.com/view/3sffzj
	//	its just a general 2D map of cloud existence
	//vec2 uv = fragCoord/iResolution.xy;
	uv -= 0.5;

	//Three overlapping circles.
	uv *= 5.0;
	float dist = circularOut(max(0.0, 1.0-length(uv)));
	uv *= 1.2;
	dist = max(dist, 0.8*circularOut(max(0.0, 1.0-length(uv+0.65))));
	uv *= 1.3;
	dist = max(dist, 0.75*circularOut(max(0.0, 1.0-length(uv-0.75))));

	vec3 col = vec3(dist);
	
	return col.x;
}

float GetCloudDensity(vec3 p, out float cloudHeight, bool sampleNoise)
{
	if(!InsideCloudBounds(p))
		return 0.0;

	
	cloudHeight = saturate((p.y - cloudStart)/(cloudEnd-cloudStart));
	float cloud = getCloudMap(p);

	// If there are no clouds, exit early.
	if(cloud <= 0.0)
	{
		return 0.0;
	}

	// Sample texture which determines how high clouds reach.
	float height = pow(cloud, 0.75);
	
	// Round the bottom and top of the clouds. From "Real-time rendering of volumetric clouds".
	cloud *= saturate(remap(cloudHeight, 0.0, 0.25 * (1.0-cloud), 0.0, 1.0))
		   * saturate(remap(cloudHeight, 0.75 * height, height, 1.0, 0.0));

	// Animate main shape.
	p += vec3(2.0 * iTime, 0.0, iTime);
	
	// Get main shape noise
	float shape = getPerlinWorleyNoise(shapeSize * p);

	// Carve away density from cloud based on noise.
	cloud = saturate(remap(cloud, shapeStrength * (shape), 1.0, 0.0, 1.0));

	// Early exit from empty space
	if(cloud <= 0.0){
	  return 0.0;
	}
	
	// Animate details.
	p += vec3(3.0 * iTime, -3.0 * iTime, iTime);
	
	// Get detail shape noise
	float detail = getPerlinWorleyNoise(detailSize * p);
	
	// Carve away detail based on the noise
	cloud = saturate(remap(cloud, detailStrength * (detail), 1.0, 0.0, 1.0));
	return densityMultiplier * cloud;
}

// Get the amount of light that reaches a sample point.
vec3 lightRay(vec3 org, vec3 p, float phaseFunction, float mu, vec3 sunDirection)
{
	return vec3(0.5);
/*
	float lightRayDistance = CLOUD_EXTENT*0.75;
	float distToStart = 0.0;
	
	getCloudIntersection(p, sunDirection, distToStart, lightRayDistance);
		
	float stepL = lightRayDistance/float(STEPS_LIGHT);

	float lightRayDensity = 0.0;
	
	float cloudHeight = 0.0;

	// Collect total density along light ray.
	for(int j = 0; j < STEPS_LIGHT; j++){
	
		bool sampleDetail = true;
		if(lightRayDensity > 0.3){
			sampleDetail = false;
		}
		
		lightRayDensity += clouds(p + sunDirection * float(j) * stepL,
								  cloudHeight, sampleDetail);
	}
	
	vec3 beersLaw = multipleOctaves(lightRayDensity, mu, stepL);
	
	// Return product of Beer's law and powder effect depending on the
	// view direction angle with the light direction.
	return mix(beersLaw * 2.0 * (1.0 - (exp( -stepL * lightRayDensity * 2.0 * sigmaE))),
			   beersLaw,
			   0.5 + 0.5 * mu);
 */
}

void GetDistanceToClouds(vec3 RayPosition,vec3 RayDirection,inout float Distance,inout vec4 Colour)
{
	//	todo: get a distance to a cloud bounds, so things can nicely step
	//		as it is, we assume we're always inside cloud
	//		with alpha, we end up doing a fixed step
	vec3 sunLight = SunColour.xyz * power;
	
	// Normalised height for shaping and ambient lighting weighting.
	float cloudHeight;
	// Get density and cloud height at sample point
	float density = GetCloudDensity(RayPosition, cloudHeight, true);
	
	vec3 sunDirection = RayPosition - SunSphere.xyz;
	float mu = dot(RayDirection, sunDirection);
	vec3 org = RayPosition;	//	eye origin?
	
	// Combine backward and forward scattering to have details in all directions.
	float phaseFunction = mix(HenyeyGreenstein(-0.3, mu), HenyeyGreenstein(0.3, mu), 0.7);
	float stepS = FIXED_STEP_DISTANCE;
	vec3 sampleSigmaS = sigmaS * density;
	vec3 sampleSigmaE = sigmaE * density;

	//	no cloud here, just ignore?
	if(density <= 0.0 )
	{
		//Colour = vec4(0,0,0,0);
		//Distance = 0.0;
		return;
	}
	
	//	already inside some solid object
	if ( Distance <= 0.0 )
		return;

	
	//	inside cloud, so specify distance as zero
	Distance = 0.0;
	Colour = vec4(1,0,0,density);
	Colour = vec4(1,0,0,0.5);
	return;
	
	//Constant lighting factor based on the height of the sample point.
	vec3 ambient = SunColour.xyz * mix((0.2), (0.8), cloudHeight);

	// Amount of sunlight that reaches the sample point through the cloud
	// is the combination of ambient light and attenuated direct light.
	vec3 luminance = 0.1 * ambient +
	sunLight * phaseFunction * lightRay(org, RayPosition, phaseFunction, mu, sunDirection);

	// Scale light contribution by density of the cloud.
	luminance *= sampleSigmaS;

	// Beer-Lambert.
	vec3 transmittance = exp(-sampleSigmaE * stepS);

	// Better energy conserving integration
	// "From Physically based sky, atmosphere and cloud rendering in Frostbite" 5.6
	// by Sebastian Hillaire.

	//	gr: this is running data
	vec3 totalTransmittance = vec3(1.0);
	vec3 colour = vec3(0);

	colour += totalTransmittance * (luminance - luminance * transmittance) / sampleSigmaE;
	Colour.xyz = colour;

	// Attenuate the amount of light that reaches the camera.
	totalTransmittance *= transmittance;

	// If ray combined transmittance is close to 0, nothing beyond this sample
	// point is visible, so break early.
	if(length(totalTransmittance) <= 0.001)
		totalTransmittance = vec3(0.0);

	//Colour.w = 1.0 - totalTransmittance.x;
	Colour.w = totalTransmittance.x;
}

void DistanceToScene(vec3 RayPosition,vec3 RayDirection,inout float Distance,inout vec4 Colour)
{
	GetDistanceToSphere( RayPosition, SunSphere, SunColour, Distance, Colour );
	GetDistanceToSphere( RayPosition, MoonSphere, MoonColour, Distance, Colour );
	GetDistanceToClouds( RayPosition, RayDirection, Distance, Colour );
}

uniform float DistancePerOpacityk;
#define DistancePerOpacity	(DistancePerOpacityk/1000.0)
//float DistancePerOpacity = 0.05;

//	march scene and get colour
//	also get position for shadowing
//	todo: get a bouncing ray for built in refraction
//	todo: get a normal
void GetSceneColour(TRay Ray,out vec4 RayMarchColour,out vec4 RayMarchPosition)
{
	const float MinDistance = 0.001;
	const float CloseEnough = MinDistance;
	const float MinStep = MinDistance;
	float FixedStepDistance = FIXED_STEP_DISTANCE;
	const float MaxDistance = FAR_Z;
	const int MaxSteps = MAX_STEPS;

	//	add noise to the ray start (this is needed whilst fixed stepping)
	//	so maybe it needs to be only when entering an alpha area
	float blueNoise = texture2D(BlueNoiseTexture,fract(uv*1.0)).x;
	// Blue noise texture is blue in space but animating it leads to white noise in time.
	// Adding golden ratio to a number yields a low discrepancy sequence (apparently),
	// making the offset of each pixel more blue in time (use fract() for modulo 1).
	// https://blog.demofox.org/2017/10/31/animating-noise-for-integration-over-time/
	//float RayOffset = fract(blueNoise + float(iFrame%32) * goldenRatio);
	float RayOffset = fract(blueNoise + 0.0 * goldenRatio);
	if ( !ApplyBlueNoiseOffset )
		RayOffset = 0.0;

	//	get an initial offset to jump start render
	float RayTime = 0.0;
	vec4 DummyColour;
	DistanceToScene( Ray.Pos, Ray.Dir, RayTime, DummyColour );
	
	
	RayTime += RayOffset;
	vec4 RayColour = vec4(0,0,0,0);
	
	//	inverse opacity, how much light gets through (demo +=bg*transmit)
	vec3 TotalTransmittance = vec3(1.0);
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = Ray.Pos + (Ray.Dir * RayTime);
		
		float SceneDistance = 999.0;
		vec4 SceneColour = vec4(1,0,1,0);
		DistanceToScene( Position, Ray.Dir, SceneDistance, SceneColour );
		
		//RayTime += max( SceneDistance, MinStep );
		//RayTime += SceneDistance;
		RayTime+=FixedStepDistance;

		//	ray gone too far
		if (RayTime > MaxDistance)
		{
			RayMarchPosition = vec4(Position,0);
			RayMarchColour = RayColour;
			return;
		}
		
		//	absorb colour (only if we hit?
		if ( SceneDistance < CloseEnough )
		{
			//	gr: we should scale the opacity with the distance we just stepped
			//		only if we were in the same object before?
			//	^^ for tweaking, we want opacity at a fixed step amount (eg. density/metre)
			//	so scale based on some unit
			//float DistancePerOpacity = 1.0;	//	1 metre is hard to tweak!
			//float DistancePerOpacity = 0.05;	//	1 metre is hard to tweak!
			float OpacityPerMetre = SceneColour.w;
			OpacityPerMetre *= FixedStepDistance / DistancePerOpacity;
			float SceneOpacityPerMetre = OpacityPerMetre * SceneColour.w;
			
			float AdditionalOpacity = min( 1.0, (1.0-RayColour.w) * SceneOpacityPerMetre);
			RayColour.xyz += SceneColour.xyz * AdditionalOpacity;
			RayColour.w += AdditionalOpacity;
			RayColour.w = min( 1.0, RayColour.w );

			//	if not opaque, move a fixed step through whatever object we hit
			if ( SceneOpacityPerMetre < 1.0 )
			{
			//if ( SceneColour.w < 1.0 )
				//RayTime += FixedStepDistance;// * (1.0-SceneColour.w);
			}
		}
		
		if ( SceneDistance < CloseEnough )
		{
			//	todo: if not opaque, need to continue and keep absorbing colour
			//	todo: bounce/refract ray here (2nd pass? we may also want to noisily pass throgh stuff)
			//		N passes? each combining? (then we can do cloud light as well as other stuff in the same way)
			if ( RayColour.w >= 1.0 )
			{
				RayMarchPosition = vec4(Position,1);
				RayMarchColour = RayColour;
				return;
			}
		}
		
		//	ray gone too far
		if (RayTime > MaxDistance)
		{
			RayMarchPosition = vec4(Position,0);
			RayMarchColour = RayColour;
			return;
		}
	}

	//	 ran out of steps
	{
		vec3 Position = Ray.Pos + Ray.Dir * RayTime;
		RayMarchPosition = vec4(Position,0);
	}
	RayMarchColour = RayColour;
}



void main()
{
	TRay Ray;
	GetWorldRay(Ray.Pos,Ray.Dir);
	vec4 Colour = vec4(BackgroundColour,0.0);

	vec4 SceneColour;
	vec4 ScenePosition;
	GetSceneColour( Ray, SceneColour, ScenePosition );

	//	miss
	/*
	if ( ScenePosition.w < 1.0 )
	{
		gl_FragColor = vec4(0,0,0,1);
		return;
	}
	*/
	Colour = mix( Colour, SceneColour, max(0.0,SceneColour.w) );
	Colour.w = 1.0;
	gl_FragColor = Colour;
	gl_FragColor.w = 1.0;
}

