precision highp float;

varying vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

uniform bool SquareStep;
uniform vec3 BackgroundColour;
#define MAX_STEPS		300
#define FAR_Z			1000.0
#define MAX_LIGHT_STEPS	100

uniform float SunPositionX;
uniform float SunPositionY;
uniform float SunPositionZ;
//const float SunRadius = 0.1;
uniform float SunRadiusk;
#define SunRadius	(SunRadiusk/1000.0)
#define SunPosition	vec3(SunPositionX,SunPositionY,SunPositionZ)
#define SunSphere	vec4(SunPosition,SunRadius)
const vec4 SunColour = vec4(1,0.9,0.3,1);

uniform float MoonPositionX;
uniform float MoonPositionY;
uniform float MoonPositionZ;
uniform float MoonRadius;
#define MoonSphere	vec4(MoonPositionX,MoonPositionY,MoonPositionZ,MoonRadius)
const vec4 MoonColour = vec4(0.1,0.1,0.9,1.0);


uniform sampler2D BlueNoiseTexture;
uniform sampler2D PerlinWorleyTexture;
const float goldenRatio = 1.61803398875;
uniform bool ApplyBlueNoiseOffset;
uniform bool ApplyDistancePerOpacity;
uniform bool LightAnyHit;



//	from https://www.shadertoy.com/view/4djSRW
//  1 out, 2 in...
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec3 hash31(float p)
{
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+33.33);
	return fract((p3.xxy+p3.yzz)*p3.zyx);
}


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

#define CLOUD_EXTENT 100.0
const float cloudStart = 0.0;
const float cloudEnd = CLOUD_EXTENT;
uniform float iTime;
#ifdef COLOUR_SCATTERING
const vec3 sigmaS = vec3(0.5, 1.0, 1.0);
#else
const vec3 sigmaS = vec3(1);
#endif
const vec3 sigmaA = vec3(0.0);

// Extinction coefficient.
const vec3 sigmaE = max(sigmaS + sigmaA, vec3(1e-6));

const float power = 200.0;

uniform float CloudDensityk;
#define CloudDensity (CloudDensityk/1000.0)

const float shapeSize = (CLOUD_EXTENT/100.0)*0.4;
const float detailSize = (CLOUD_EXTENT/100.0)*0.8;

const float shapeStrength = 0.6;
const float detailStrength = 0.35;

uniform float FixedStepDistancek;
//#define FIXED_STEP_DISTANCE 0.0110
#define FIXED_STEP_DISTANCE (FixedStepDistancek/10000.0)
#define FIXED_LIGHT_STEP_DISTANCE (FIXED_STEP_DISTANCE * (float(MAX_STEPS)/float(MAX_LIGHT_STEPS)))


uniform float DistancePerOpacityk;
#define DistancePerOpacity	(DistancePerOpacityk/1000.0)
//float DistancePerOpacity = 0.05;

uniform float BounceOffsetDistancek;
#define BounceOffsetDistance	(BounceOffsetDistancek/10000.0)

uniform float LightScatterk;
#define LightScatter	(LightScatterk/1000.0)

uniform float MinAtmosphereCloudk;
#define MinAtmosphereCloud	(MinAtmosphereCloudk/100000.0)

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
	//vec2 PerlinWorleyTextureSize = textureSize(PerlinWorleyTexture);
	vec2 PerlinWorleyTextureSize = vec2(640,360);

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
	vec2 uv = mod(pixel, dataWidth)/PerlinWorleyTextureSize.xy;
	uv.y = 1.0-uv.y;
	vec2 data = texture2D(PerlinWorleyTexture, uv).xy;
	return mix(data.x, data.y, f);
}

//	positive = distance, negative is a density inside
float DistanceToCloudBounds(vec3 p)
{
	vec4 Colour = vec4(1);
	float CloudCenterY = 0.5;
	float CloudBottomY = 0.4;
	vec4 a = vec4( 0.3, CloudCenterY, 0.0, 0.4 );
	vec4 b = vec4( 0.9, CloudCenterY, 0.0, 0.6 );
	vec4 c = vec4( 1.3, CloudCenterY, 0.0, 0.5 );

	float Distance = 999.0;
	GetDistanceToSphere( p, a, Colour, Distance, Colour );
	GetDistanceToSphere( p, b, Colour, Distance, Colour );
	GetDistanceToSphere( p, c, Colour, Distance, Colour );

	//	clip to y>0
	Distance = max( Distance, CloudBottomY-p.y);
	
	
/*
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
	return dist;
 */
	return Distance;
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

	//return 1.0;
	
	return dist;
}

bool InsideCloudBounds(vec3 Position)
{
	Position *= CLOUD_EXTENT;
	vec2 uv = 0.5 + 0.5 * (Position.xz/(1.8 * CLOUD_EXTENT));
	if ( uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0 )
		return false;
	return true;
	
	float DistanceToMap = DistanceToCloudBounds(Position);
	if ( DistanceToMap > 0.0 )
		return false;
	return true;
}


float GetCloudDensity(vec3 p, out float cloudHeight, bool sampleNoise)
{
	if ( !InsideCloudBounds(p) )
		return 0.0;
	/*
	float cloud = DistanceToCloudBounds(p);
	if ( cloud > 0.0 )
		return 0.0;
	//return CloudDensity;
	//return -cloud*CloudDensity;
	//cloud = 1.0-cloud;
	
	cloud *= -100.0;
	 */
	//	everything in here is original source-scale
	p *= CLOUD_EXTENT;
	
	float cloud = getCloudMap(p);


	cloudHeight = saturate((p.y - cloudStart)/(cloudEnd-cloudStart));
	//float cloud = DistanceToCloudBounds(p);

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

	//return cloud * CloudDensity;
	
	// Early exit from empty space
	if ( cloud <= 0.0 )
	{
		return 0.0;
	}
	
	// Animate details.
	p += vec3(3.0 * iTime, -3.0 * iTime, iTime);
	
	// Get detail shape noise
	float detail = getPerlinWorleyNoise(detailSize * p);
	
	// Carve away detail based on the noise
	cloud = saturate(remap(cloud, detailStrength * (detail), 1.0, 0.0, 1.0));
	return cloud * CloudDensity;
}

// Get the amount of light that reaches a sample point.
vec3 lightRay(vec3 org, vec3 p, float phaseFunction, float mu, vec3 sunDirection)
{
	float lightRayDistance = CLOUD_EXTENT*0.75;
	float distToStart = 0.0;
	
	//	this func is to get ray entry & exit for bounds
	//getCloudIntersection(p, sunDirection, distToStart, lightRayDistance);
		
	float stepL = lightRayDistance/float(MAX_LIGHT_STEPS);

	float lightRayDensity = 0.0;
	
	float cloudHeight = 0.0;

	// Collect total density along light ray.
	for(int j = 0; j < MAX_LIGHT_STEPS; j++)
	{
	
		bool sampleDetail = true;
		if(lightRayDensity > 0.3){
			sampleDetail = false;
		}
		
		lightRayDensity += GetCloudDensity(p, cloudHeight, true);
		//lightRayDensity += clouds(p + sunDirection * float(j) * stepL, cloudHeight, sampleDetail);
	}
	
	return vec3(lightRayDensity);
	/*
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
	//	todo: check bounds here, but we need a distance
	//if ( !InsideCloudBounds(RayPosition) )
	//	return;

	//	todo: get a distance to a cloud bounds, so things can nicely step
	//		as it is, we assume we're always inside cloud
	//		with alpha, we end up doing a fixed step
	vec3 sunLight = SunColour.xyz * power;
	
	// Normalised height for shaping and ambient lighting weighting.
	float cloudHeight;
	// Get density and cloud height at sample point
	float density = GetCloudDensity(RayPosition, cloudHeight, true);
	
	vec3 sunDirection = SunSphere.xyz - RayPosition;
	float mu = dot(RayDirection, sunDirection);

	vec3 EyePos,EyeDir;
	GetWorldRay(EyePos,EyeDir);
	vec3 org = EyePos;	//	eye origin?

	
	// Combine backward and forward scattering to have details in all directions.
	float phaseFunction = mix(HenyeyGreenstein(-0.3, mu), HenyeyGreenstein(0.3, mu), 0.7);
	float stepS = FIXED_STEP_DISTANCE;
	vec3 sampleSigmaS = sigmaS * density;
	vec3 sampleSigmaE = sigmaE * density;

	//	no cloud here, just ignore?
	if ( false )//gr: we end up stepping past the entire cloud
	if(density <= 0.0 )
	{
		//Colour = vec4(0,0,0,0);
		//Distance = 0.0;
		return;
	}
	
	//	already inside some solid object
	//	todo: handle non solids too
	if ( Distance <= 0.0 )
		return;

	
	//	inside cloud, so specify distance as zero
	Distance = 0.0;
	Colour = vec4(0,0,0,density);
	//Colour = vec4(1,0,0,0.5);
	
	//	dont light cloud
	return;
	
	//Constant lighting factor based on the height of the sample point.
	//vec3 ambient = SunColour.xyz * mix((0.2), (0.8), cloudHeight);
	vec3 ambient = SunColour.xyz;
	//vec3 ambient = vec3(0);	//	gr: no ambient colour for now

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
	colour = min( vec3(1.0), colour );
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


void GetDistanceToCloudBounds(vec3 RayPosition,vec3 RayDirection,inout float Distance,inout vec4 Colour)
{
	float BoundsDist = DistanceToCloudBounds( RayPosition );
	if ( BoundsDist < Distance )
	{
		Distance = BoundsDist;
		Colour = vec4(0,1,0,1);
	}

}

void DistanceToSceneDensity(vec3 RayPosition,vec3 RayDirection,inout float Distance,inout float Density)
{
	vec4 Colour = vec4(0);
	GetDistanceToSphere( RayPosition, SunSphere, SunColour, Distance, Colour );
	GetDistanceToSphere( RayPosition, MoonSphere, MoonColour, Distance, Colour );
	GetDistanceToClouds( RayPosition, RayDirection, Distance, Colour );
	Density = Colour.w;
}


void DistanceToScene(vec3 RayPosition,vec3 RayDirection,inout float Distance,inout vec4 Colour)
{
	GetDistanceToSphere( RayPosition, SunSphere, SunColour, Distance, Colour );
	GetDistanceToSphere( RayPosition, MoonSphere, MoonColour, Distance, Colour );
	GetDistanceToClouds( RayPosition, RayDirection, Distance, Colour );
	//GetDistanceToCloudBounds( RayPosition, RayDirection, Distance, Colour );
}

vec2 hash23(vec3 p3)
{
	p3 = fract(p3 * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+33.33);
	return fract((p3.xx+p3.yz)*p3.zy);
}

float GetBlueNoise(vec3 RayDir)
{
	vec2 Sample = hash23(RayDir);
	//vec2 Sample = fract(RayDir.xy*0.7777);
	float blueNoise = texture2D(BlueNoiseTexture,Sample).x;
	blueNoise = fract(blueNoise + 0.0 * goldenRatio);
	return blueNoise;
}


float GetNoisyRayOffset(vec3 RayDir)
{
	float BlueNoise = GetBlueNoise(RayDir);
	float RayOffset = BlueNoise;
	if ( !ApplyBlueNoiseOffset )
		RayOffset = 0.0;

	return RayOffset * FIXED_STEP_DISTANCE;
}


//	march toward A light
//	returns 0-1 of (1-obstruction)
float GetLightVisibility(vec3 RayStart,vec4 LightSphere,float LightNoise)
{
	const float MinDistance = 0.001;
	const float CloseEnough = MinDistance;
	const float MaxDistance = FAR_Z;
	const int MaxSteps = MAX_LIGHT_STEPS;

	vec3 RayDir = normalize(LightSphere.xyz - RayStart);
	
	//	apply some randomness to the light vector
	float Noise = GetBlueNoise(RayDir);
	vec3 Noise3 = (hash31(Noise) - vec3(0.5)) * vec3(2.0);
	RayDir += Noise3 * LightNoise;
	RayDir = normalize(RayDir);

	//	time=distance
	float RayTime = BounceOffsetDistance;	//	start past surface of where we start
	RayTime += GetNoisyRayOffset(RayDir);
	
	
	//	how much thick stuff have we passed through
	float Density = 0.0;
	
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = RayStart + (RayDir * RayTime);
		
		float SceneDistance = 999.0;
		float SceneDensity = 0.0;
		DistanceToSceneDensity( Position, RayDir, SceneDistance, SceneDensity );
		
		//	hit we the light we're aiming for
		//	gr: should this be part of the scene march?
		{
			float DistanceToLight = length(LightSphere.xyz - Position) - LightSphere.w;
			if ( DistanceToLight < CloseEnough )
				return 1.0-Density;
		}
		
		if ( true )
		{
			RayTime += FIXED_LIGHT_STEP_DISTANCE;
		}
		else
		{
			if ( SceneDistance < CloseEnough && SceneDensity < 1.0 )
				RayTime += FIXED_LIGHT_STEP_DISTANCE;
			else
				RayTime += SceneDistance;
		}

		//	if we hit/inside something, accumulate the density
		if ( SceneDistance < CloseEnough )
		{
			Density += SceneDensity;
		}

		//	ray gone too far
		if ( RayTime > MaxDistance )
			return 1.0 - Density;
		
		//	light is blocked
		if ( Density >= 1.0 )
			return 1.0 - Density;
	}
	
	//	never hit the light
	return 0.0;
	return 1.0 - Density;
}






//	simplifying down to just accumulate light
void GetSceneLight(TRay Ray,out float FinalHitLight,out vec4 FinalHitPosition)
{
	const float MinDistance = 0.01;
	const float CloseEnough = MinDistance;
	const float MaxDistance = FAR_Z;
	const int MaxSteps = MAX_STEPS;


	//	time=distance
	float RayTime = 0.0;
	RayTime += GetNoisyRayOffset(Ray.Dir);

	//	the amount of light we've accumulated
	float RayLight = 0.0;
	//	how much solid matter have we passed through
	float RayDensity = 0.0;
	
	vec3 LastPosition = Ray.Pos;
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = Ray.Pos + (Ray.Dir * RayTime);
		
		float SceneDistance = 999.0;
		vec4 SceneColour = vec4(1,0,1,0);
		DistanceToScene( Position, Ray.Dir, SceneDistance, SceneColour );
		
		//	inside something translucent, do fixed step
		//	if we're inside something translucent we should scatter/refract the ray
		//	gr: scatter only for light?
		if ( SceneDistance < CloseEnough && SceneColour.w < 1.0 )
			RayTime += FIXED_STEP_DISTANCE;
		else
			RayTime += SceneDistance;
		float LastStepDistance = length(Position-LastPosition);
		
		//	ray gone too far
		if ( RayTime > MaxDistance )
		{
			FinalHitPosition = vec4(Position,1);
			FinalHitLight = RayLight;
			return;
		}

		
		//	this should scale with fixed steps
		float StepDensity = SceneColour.w;
		float OpacityPerMetre = StepDensity;
		//OpacityPerMetre *= LastStepDistance / DistancePerOpacity;
		OpacityPerMetre *= FIXED_STEP_DISTANCE / DistancePerOpacity;
		if ( ApplyDistancePerOpacity )
			if ( StepDensity < 1.0 )	//	dont apply density scaling if we've just intersected with something
				StepDensity = OpacityPerMetre;
		StepDensity = min(1.0,StepDensity);
		//StepDensity = max( MinAtmosphereCloud, StepDensity );
		if ( SceneDistance < CloseEnough && StepDensity>0.0)
		{
			float LightHere = GetLightVisibility( Position, SunSphere, LightScatter );
			
			StepDensity = max( MinAtmosphereCloud, StepDensity );
			
			RayDensity += StepDensity;
			RayLight += LightHere * StepDensity;
			
			//RayLight += 1.0 * MinAtmosphereCloud;
			
			if ( LightAnyHit )
				RayLight += 1.0;	//	make all steps hit

			//	only stop if the thing we hit is opaque
			//	gr: do we stop if the density has hit 1?
			//if ( SceneColour.w >= 1.0 )
			if ( RayDensity >= 1.0 )
			{
				//	visualise
				FinalHitPosition = vec4(Position,1);
				FinalHitLight = RayLight;
				return;
			}

		}
		else
		{
			//	general atmosphere ambience
			float LightHere = 1.0;
			RayLight += LightHere * MinAtmosphereCloud;
		}
		LastPosition = Position;
	}

	//	 ran out of steps
	{
		vec3 Position = Ray.Pos + Ray.Dir * RayTime;
		FinalHitPosition = vec4(Position,1);
	}
	FinalHitLight = RayLight;
}


void GetSceneColour(TRay Ray,out vec4 RayColour,out vec4 HitPosition)
{
	//	for now just visualise the light
	float Light = 0.0;
	GetSceneLight( Ray, Light, HitPosition );

	if ( HitPosition.w == 0.0 )
	{
		RayColour = vec4(0,0,1,1);
		return;
	}

	RayColour.xyz = vec3(Light);
	RayColour.w = 1.0;
}


void main()
{
	TRay Ray;
	GetWorldRay(Ray.Pos,Ray.Dir);
	vec4 Colour = vec4(BackgroundColour,0.0);
	Colour = vec4(0.2,0.9,0.4,0);
	//Colour = vec4(0);

	vec4 SceneColour;
	vec4 ScenePosition;
	GetSceneColour( Ray, SceneColour, ScenePosition );

	//	miss gr: this include inside cloud
	/*
	if ( ScenePosition.w < 1.0 )
	{
		gl_FragColor = vec4(0,0,0,1);
		return;
	}
	*/
	Colour = mix( Colour, SceneColour, max(0.0,SceneColour.w) );
	//Colour.xyz += SceneColour.xyz * SceneColour.www;
	Colour.w = 1.0;
	gl_FragColor = Colour;
	gl_FragColor.w = 1.0;

}

