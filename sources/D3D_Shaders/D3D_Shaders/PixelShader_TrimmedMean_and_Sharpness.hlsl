// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


//#define EFFECTLOOP_ENABLED


#define MAX_EFFECTLEVEL 3
#define MAX_EFFECTMODE 3

#ifndef EFFECTLOOP_ENABLED
#define MAX_EFFECTLOOP 1
#else
#define MAX_EFFECTLOOP 2
#endif


#include "PixelShader.hlsli"


//----------------------------------------------------------------------
// trimmed mean

#ifndef EFFECTLOOP_ENABLED
static const float PresetKernelDataSamplingOffset_Mean[3] =
{
	0.8f,		1.3f,		1.8f		// magnification 2, 3, 4
};

static const float KernelDataSamplingOffset_Mean = PresetKernelDataSamplingOffset_Mean[RenderMagnification - 2];
#else
static const float PresetKernelDataSamplingOffset_Mean[3] =
{
	0.6f,		1.1f,		1.5f		// magnification 2, 3, 4
};

static const float KernelDataSamplingOffset_Mean = PresetKernelDataSamplingOffset_Mean[RenderMagnification - 2];
#endif


static const float PresetKernelDataSamplingOffset_Min[3] =
{
	0.25f,		0.5f,		0.85f		// magnification 2, 3, 4
};

static const float KernelDataSamplingOffset_Min = PresetKernelDataSamplingOffset_Min[RenderMagnification - 2];


void Sort( inout float3 colors[KernelDataCount3x3] )
{
	int i, j;
	float3 lesser_values, greater_values;
	
	for(i = KernelDataCount3x3; i > 0 ; --i)
	{
		for( j = 0; j < (i - 1); ++j )
		{
			lesser_values = min( colors[j], colors[j + 1] );
			greater_values = max( colors[j], colors[j + 1] );
			
			colors[j] = lesser_values;
			colors[j + 1] = greater_values;
		}
	}
}

float3 TrimmedMean(const float2 uv, const float3 original_color, const bool is_highreso)
{
	const float sampling_offset = is_highreso ? KernelDataSamplingOffset_Min : KernelDataSamplingOffset_Mean;
	
	float3 colors[KernelDataCount3x3];
	
	colors[4] = original_color;
	
	colors[0] = GetTexel(	uv,		-sampling_offset,		-sampling_offset		);
	colors[1] = GetTexel(	uv,		0.0f,					-sampling_offset		);
	colors[2] = GetTexel(	uv,		sampling_offset,		-sampling_offset		);
	
	colors[3] = GetTexel(	uv,		-sampling_offset,		0.0f					);
	colors[5] = GetTexel(	uv,		sampling_offset,		0.0f					);
	
	colors[6] = GetTexel(	uv,		-sampling_offset,		sampling_offset			);
	colors[7] = GetTexel(	uv,		0.0f,					sampling_offset			);
	colors[8] = GetTexel(	uv,		sampling_offset,		sampling_offset			);
	
	Sort(colors);
	
	switch(EffectMode)
	{
		case 2:
		case 3:
			#if 1
			return ( ( colors[2] + colors[3] + colors[4] + colors[5] + colors[6] ) / 5.0f );
			#else
			return ( ( ( colors[1] * 0.25f ) + colors[2] + colors[3] + colors[4] + colors[5] + colors[6] + ( colors[7] * 0.25f ) ) / 5.5f );
			#endif
		
		default:
			return ( ( colors[1] + colors[2] + colors[3] + colors[4] + colors[5] + colors[6] + colors[7] ) / 7.0f );
	}
}


//----------------------------------------------------------------------
// unsharp mask

static const float PresetKernelDataSamplingOffset_Sharpness[3] =
{
//	0.7f,		1.0f,		1.5f		// magnification 2, 3, 4
	0.8f,		1.3f,		1.8f
};

static const float KernelDataSamplingOffset_Sharpness = PresetKernelDataSamplingOffset_Sharpness[RenderMagnification - 2];


#ifndef EFFECTLOOP_ENABLED
static const float PresetUnsharpMaskCoef[4][4] =
{
//	{	0.5f,		1.0f,		1.5f,		2.0f		},
//	{	0.5f,		1.0f,		1.5f,		2.0f		},
//	{	0.4f,		0.6f,		0.8f,		1.0f		},
//	{	0.4f,		0.6f,		0.8f,		1.0f		}
	
	{	0.5f,		1.0f,		1.4f,		1.8f		},
	{	0.5f,		1.0f,		1.4f,		1.8f		},
	{	0.4f,		0.6f,		0.8f,		1.0f		},
	{	0.4f,		0.6f,		0.8f,		1.0f		}
};

static const float UnsharpMaskCoef = PresetUnsharpMaskCoef[EffectMode][EffectLevel];
#else
static const float PresetUnsharpMaskCoef[4][4] =
{
	{	2.0f,		2.5f,		3.0f,		3.5f		},
	{	2.0f,		2.5f,		3.0f,		3.5f		},
	{	1.25f,		1.5f,		1.75f,		2.0f		},
	{	1.25f,		1.5f,		1.75f,		2.0f		}
};

static const float UnsharpMaskCoef = PresetUnsharpMaskCoef[EffectMode][EffectLevel];
#endif


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

#ifndef EFFECTLOOP_ENABLED
// trimmed mean単発ver

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
//	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv);
	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv);
	
	if(EffectLoopCount == 0)
		return TrimmedMean(uv, original_color, is_highreso);
	
	if(is_highreso)
		return original_color;
	
	return UnsharpMask(uv, original_color);
}
#else
// trimmed mean複数回適用ver
// 画質は良好だがGPU負荷が高く実行速度が低下する場合がある

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
//	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv);
	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv);
	
	if(EffectLoopCount == 0)
		return TrimmedMean(uv, original_color, is_highreso);
	
	if(is_highreso)
		return original_color;
	
	if(EffectLoopCount == 1)
		return TrimmedMean(uv, original_color, false);		// trimmed meanを2回重ねがけ
	
	return UnsharpMask(uv, original_color);
}
#endif
