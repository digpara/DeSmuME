// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


#define MAX_EFFECTLEVEL 3
#define MAX_EFFECTMODE 3
#define MAX_EFFECTLOOP 0


#include "PixelShader.hlsli"


//----------------------------------------------------------------------
// gaussian

static const int SamplingOffset_End = RenderMagnification - 1;
static const int SamplingOffset_Begin = -SamplingOffset_End;


static const float PresetGaussianSigma[3][4] =
{
//	{	0.5f,		0.6f,		0.8f,		1.05f		},		// magnification 2: 3x3 kernel
//	{	0.6f,		0.8f,		1.0f,		1.2f		},		// magnification 3: 5x5 kernel
//	{	0.7f,		1.1f,		1.3f,		1.55f		}		// magnification 4: 7x7 kernel

	{	0.4f,		0.525f,		0.65f,		0.9f		},
	{	0.55f,		0.75f,		1.0f,		1.4f		},
	{	0.75f,		1.0f,		1.4f,		1.9f		}
};

static const float GaussianSigma = PresetGaussianSigma[RenderMagnification - 2][EffectLevel];
static const float GaussianSigma2 = (2.0f * GaussianSigma * GaussianSigma);
static const float GaussianSigma1 = 1.0f / (Pi * GaussianSigma2);

inline float GetGaussianCoef(const float offset_u, const float offset_v)
{
	return ( GaussianSigma1 * exp( -( (offset_u * offset_u) + (offset_v * offset_v) ) / GaussianSigma2 ) );
}

static const float GaussianSigma_Min = PresetGaussianSigma[RenderMagnification - 2][0];
static const float GaussianSigma_Min2 = (2.0f * GaussianSigma_Min * GaussianSigma_Min);
static const float GaussianSigma_Min1 = 1.0f / (Pi * GaussianSigma_Min2);

inline float GetGaussianCoef_Min(const float offset_u, const float offset_v)
{
	return ( GaussianSigma_Min1 * exp( -( (offset_u * offset_u) + (offset_v * offset_v) ) / GaussianSigma_Min2 ) );
}


//static const float PresetBilateralSigma = 0.5f;
//static const float PresetBilateralSigma = 0.6f;
static const float PresetBilateralSigma = 0.7f;
//static const float PresetBilateralSigma = 0.8f;
static const float BilateralSigma1 = PresetBilateralSigma * PresetBilateralSigma * 2.0f;

inline float GetBilateralCoef(const float intensity_delta)
{
	return exp( -(intensity_delta * intensity_delta) / BilateralSigma1 );
}


float3 Gaussian(const float2 uv, const float3 original_color)
{
//	const bool is_highreso = (EffectLevel > 0) && ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv);
	const bool is_highreso = (EffectLevel > 0) && ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv);
	const float original_intensity = GetColorIntensity(original_color);
	
	float3 total_values = 0.0f;
	float total_coef = 0.0f;
	
	int u_offset, v_offset;
	float3 color;
	float coef;
	
	for(v_offset = SamplingOffset_Begin; v_offset <= SamplingOffset_End; ++v_offset)
	{
		for(u_offset = SamplingOffset_Begin; u_offset <= SamplingOffset_End; ++u_offset)
		{
			color = GetTexel(uv, u_offset, v_offset);
			coef = is_highreso ? GetGaussianCoef_Min(u_offset, v_offset) : GetGaussianCoef(u_offset, v_offset);		// high-resolution area‚È‚çeffect level‚ðÅŽã‚É‚·‚é
			
			if(EffectMode >= 2)
				coef *= GetBilateralCoef( GetColorIntensity(color) - original_intensity );
			
			total_values += color * coef;
			total_coef += coef;
		}
	}
	
	return (total_values / total_coef);
}


//----------------------------------------------------------------------

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
	return Gaussian(uv, original_color);
}
