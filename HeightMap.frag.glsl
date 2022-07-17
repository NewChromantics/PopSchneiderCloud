precision highp float;

varying vec2 uv;
uniform mat4 ScreenToCameraTransform;
uniform mat4 CameraToWorldTransform;

uniform bool SquareStep;
uniform vec3 BackgroundColour;
#define MAX_STEPS	120
#define FAR_Z		1000.0

uniform float SunPositionX;
uniform float SunPositionY;
uniform float SunPositionZ;
const float SunRadius = 0.1;
#define SunPosition	vec3(SunPositionX,SunPositionY,SunPositionZ)
#define SunSphere	vec4(SunPosition,SunRadius)
const vec4 SunColour = vec4(1,1,0.3,1);

uniform vec4 MoonSphere;// = vec4(0,0,-3,1.0);
const vec4 MoonColour = vec4(0.9,0.9,0.9,1.0);

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
/*
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
*/

//	gr: returning a TRay, or using TRay as an out causes a very low-precision result...
void GetWorldRay(out vec3 RayPos,out vec3 RayDir)
{
	float Near = 0.01;
	float Far = FAR_Z;
	RayPos = ScreenToWorld( uv, Near );
	RayDir = ScreenToWorld( uv, Far ) - RayPos;
	
	//	gr: this is backwards!
	RayDir = -normalize( RayDir );

	//	mega bodge for webxr views
	//	but, there's something wrong with when we pan (may be using old broken camera code)
	if ( RayDir.z < 0.0 )
	{
		//RayDir *= -1.0;
	}
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



void DistanceToScene(vec3 RayPosition,inout float Distance,inout vec4 Colour)
{
	GetDistanceToSphere( RayPosition, SunSphere, SunColour, Distance, Colour );
	GetDistanceToSphere( RayPosition, MoonSphere, MoonColour, Distance, Colour );
}

//	march scene and get colour
//	also get position for shadowing
//	todo: get a bouncing ray for built in refraction
//	todo: get a normal
void GetSceneColour(TRay Ray,out vec4 RayMarchColour,out vec4 RayMarchPosition)
{
	const float MinDistance = 0.001;
	const float CloseEnough = MinDistance;
	const float MinStep = MinDistance;
	const float FixedStepDistance = 0.01;
	const float MaxDistance = FAR_Z;
	const int MaxSteps = MAX_STEPS;
	
	float RayTime = 0.0;
	vec4 RayColour = vec4(0,1,0,0);
	
	for ( int s=0;	s<MaxSteps;	s++ )
	{
		vec3 Position = Ray.Pos + (Ray.Dir * RayTime);
		
		float SceneDistance = 999.0;
		vec4 SceneColour = vec4(1,0,1,0);
		DistanceToScene( Position, SceneDistance, SceneColour );
		
		//RayTime += max( SceneDistance, MinStep );
		RayTime += SceneDistance;

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
			float AdditionalOpacity = min( 1.0, (1.0-RayColour.w) * SceneColour.w );
			RayColour.xyz += SceneColour.xyz * AdditionalOpacity;
			RayColour.w += AdditionalOpacity;
			RayColour.w = min( 1.0, RayColour.w );

			//	if not opaque, move a fixed step through whatever object we hit
			//if ( SceneColour.w < 1.0 )
			//	RayTime += FixedStepDistance;
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

