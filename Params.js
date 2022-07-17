class Params_t
{
	get MoonSphere()	{	return [this.MoonPositionX,this.MoonPositionY,this.MoonPositionZ,this.MoonRadius];	}
}
export const Params = new Params_t();
export default Params;

Params.DistancePerOpacityk = 0.05*1000;
Params.ApplyBlueNoiseOffset = false;
Params.SunPositionX = 0;
Params.SunPositionY = 1;
Params.SunPositionZ = -2;
Params.FixedStepDistance = 0.100*10000;
Params.BackgroundColour = [1,1,1];
Params.Fov = 52;
Params.MoonPositionX = 0;
Params.MoonPositionY = 0.6;
Params.MoonPositionZ = -0.2;
Params.MoonRadius = 0.5;
Params.XrToMouseScale = 100;	//	metres to pixels

export const ParamsMeta = {};

ParamsMeta.SunPositionX = {min:-10,max:10,step:0.1};
ParamsMeta.SunPositionY = {min:-10,max:10,step:0.1};
ParamsMeta.SunPositionZ = {min:-10,max:10,step:0.1};
ParamsMeta.MoonPositionX = {min:-10,max:10,step:0.1};
ParamsMeta.MoonPositionY = {min:-10,max:10,step:0.1};
ParamsMeta.MoonPositionZ = {min:-10,max:10,step:0.1};
ParamsMeta.MoonRadius = {min:0,max:10,step:0.1};
ParamsMeta.FixedStepDistance = {min:1,max:1000,step:0.01};
ParamsMeta.DistancePerOpacityk = {min:1,max:100,step:0.01};


ParamsMeta.TextureSampleColourMult = {min:0,max:2};
ParamsMeta.TextureSampleColourAdd = {min:-1,max:1};
ParamsMeta.AmbientOcclusionMin = {min:0,max:1};
ParamsMeta.AmbientOcclusionMax = {min:0,max:1};
ParamsMeta.BaseColour = {type:'Colour'};
ParamsMeta.BackgroundColour = {type:'Colour'};
ParamsMeta.TerrainHeightScalar = {min:0,max:5};
ParamsMeta.Fov = {min:10,max:90};
ParamsMeta.BrightnessMult = {min:0,max:10};
ParamsMeta.HeightMapStepBack = {min:0,max:1};
ParamsMeta.StepHeatMax = {min:0,max:1};

