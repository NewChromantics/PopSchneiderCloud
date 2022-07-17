export const Params = {};
export default Params;

Params.DistancePerOpacityk = 0.05*1000;
Params.ApplyBlueNoiseOffset = false;
Params.SunPositionX = 0;
Params.SunPositionY = 1;
Params.SunPositionZ = -2;
Params.FixedStepDistance = 0.010*10000;
Params.BackgroundColour = [0,0,0];
Params.Fov = 52;
Params.MoonSphere = [0,0.6,-0.2,0.5];
Params.XrToMouseScale = 100;	//	metres to pixels

export const ParamsMeta = {};

ParamsMeta.SunPositionX = {min:-10,max:10,step:0.1};
ParamsMeta.SunPositionY = {min:-10,max:10,step:0.1};
ParamsMeta.SunPositionZ = {min:-10,max:10,step:0.1};
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

