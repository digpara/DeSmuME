// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


#define MAX_EFFECTLEVEL 3
#define MAX_EFFECTMODE 3
#define MAX_EFFECTLOOP 1


#include "PixelShader.hlsli"


//----------------------------------------------------------------------
// gaussian

static const int SamplingOffset_End = RenderMagnification - 1;
static const int SamplingOffset_Begin = -SamplingOffset_End;


static const float PresetGaussianSigma[3] =
{
//	0.9f,		// magnification 2: 3x3 kernel
//	1.4f,		// magnification 3: 5x5 kernel
//	1.9f		// magnification 4: 7x7 kernel

	0.7f,
	1.2f,
	1.7f
};

static const float GaussianSigma = PresetGaussianSigma[RenderMagnification - 2];
static const float GaussianSigma2 = (2.0f * GaussianSigma * GaussianSigma);
static const float GaussianSigma1 = 1.0f / (Pi * GaussianSigma2);

inline float GetGaussianCoef(const float offset_u, const float offset_v)
{
	return ( GaussianSigma1 * exp( -( (offset_u * offset_u) + (offset_v * offset_v) ) / GaussianSigma2 ) );
}


static const float PresetGaussianSigma_Min[3] =
{
	0.4f,		// magnification 2: 3x3 kernel
	0.55f,		// magnification 3: 5x5 kernel
	0.75f		// magnification 4: 7x7 kernel
};

static const float GaussianSigma_Min = PresetGaussianSigma_Min[RenderMagnification - 2];
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


float3 Gaussian(const float2 uv, const float3 original_color, const bool is_highreso)
{
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
// unsharp mask

static const float PresetKernelDataSamplingOffset_Sharpness[3] =
{
//	0.9f,		1.4f,		1.9f		// magnification 2, 3, 4
	0.5f,		1.0f,		1.5f
};

static const float KernelDataSamplingOffset_Sharpness = PresetKernelDataSamplingOffset_Sharpness[RenderMagnification - 2];


static const float PresetUnsharpMaskCoef[4][4] =
{
//	{	1.5f,		2.0f,		2.5f,		3.0f		},
//	{	1.5f,		2.0f,		2.5f,		3.0f		},
//	{	0.5f,		0.9f,		1.2f,		1.6f		},
//	{	0.5f,		0.9f,		1.2f,		1.6f		}

	{	1.0f,		1.5f,		2.0f,		2.5f		},
	{	1.0f,		1.5f,		2.0f,		2.5f		},
	{	0.4f,		0.8f,		1.2f,		1.5f		},
	{	0.4f,		0.8f,		1.2f,		1.5f		}
};

static const float UnsharpMaskCoef = PresetUnsharpMaskCoef[EffectMode][EffectLevel];
static const float UnsharpMaskCoef_Center = 1.0f + ( (8.0f * UnsharpMaskCoef) / 9.0f );
static const float UnsharpMaskCoef_Periphery = -UnsharpMaskCoef / 9.0f;


float3 UnsharpMask(const float2 uv, const float3 original_color)
{
	return
	(
		original_color * UnsharpMaskCoef_Center +
		
		GetTexel(	uv,		-KernelDataSamplingOffset_Sharpness,		-KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery +
		GetTexel(	uv,		0.0f,										-KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery +
		GetTexel(	uv,		KernelDataSamplingOffset_Sharpness,			-KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery +
		
		GetTexel(	uv,		-KernelDataSamplingOffset_Sharpness,		0.0f									) * UnsharpMaskCoef_Periphery +
		GetTexel(	uv,		KernelDataSamplingOffset_Sharpness,			0.0f									) * UnsharpMaskCoef_Periphery +
		
		GetTexel(	uv,		-KernelDataSamplingOffset_Sharpness,		KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery +
		GetTexel(	uv,		0.0f,										KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery +
		GetTexel(	uv,		KernelDataSamplingOffset_Sharpness,			KernelDataSamplingOffset_Sharpness		) * UnsharpMaskCoef_Periphery
	);
}


//----------------------------------------------------------------------

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
//	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv);
	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv);
	
	if(EffectLoopCount == 0)
		return Gaussian(uv, original_color, is_highreso);
	
	if(is_highreso)
		return original_color;
	
	return UnsharpMask(uv, original_color);
}
