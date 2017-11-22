// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


//#define EFFECTLOOP_ENABLED		0


#define MAX_EFFECTLEVEL 3
#define MAX_EFFECTMODE 3

#ifndef EFFECTLOOP_ENABLED
#define MAX_EFFECTLOOP 0
#elif (EFFECTLOOP_ENABLED > 1)
#define MAX_EFFECTLOOP 4
#else
#define MAX_EFFECTLOOP 1
#endif


#include "PixelShader.hlsli"


//----------------------------------------------------------------------
// trimmed mean

#ifndef EFFECTLOOP_ENABLED
static const float PresetKernelDataSamplingOffset[3][4] =
{
//	{	0.3f,		0.5f,		0.7f,		0.9f		},		// magnification 2
//	{	0.6f,		1.0f,		1.2f,		1.4f		},		// magnification 3
//	{	0.9f,		1.3f,		1.6f,		1.9f		}		// magnification 4
	
	{	0.25f,		0.4f,		0.6f,		0.8f		},
	{	0.5f,		0.8f,		1.1f,		1.3f		},
	{	0.85f,		1.2f,		1.5f,		1.8f		}
};

static const float KernelDataSamplingOffset = PresetKernelDataSamplingOffset[RenderMagnification - 2][EffectLevel];
static const float KernelDataSamplingOffset_Min = PresetKernelDataSamplingOffset[RenderMagnification - 2][0];
#elif (EFFECTLOOP_ENABLED > 1)

static const float PresetKernelDataSamplingOffset[3] =
{
//	0.3f,		0.6f,		0.9f		// magnification 2, 3, 4
	0.25f,		0.5f,		0.85f
};

static const float KernelDataSamplingOffset = PresetKernelDataSamplingOffset[RenderMagnification - 2];
#else
static const float PresetKernelDataSamplingOffset[3][3] =
{
	{	0.25f,		0.4f,		0.6f		},		// magnification 2
	{	0.5f,		0.8f,		1.1f		},		// magnification 3
	{	0.85f,		1.2f,		1.5f		} 		// magnification 4
};

static const float KernelDataSamplingOffset = PresetKernelDataSamplingOffset[RenderMagnification - 2][EffectLevel - 1];
static const float KernelDataSamplingOffset_Min = PresetKernelDataSamplingOffset[RenderMagnification - 2][0];
#endif


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
	#if !defined(EFFECTLOOP_ENABLED) || (EFFECTLOOP_ENABLED == 0)
	const float sampling_offset = is_highreso ? KernelDataSamplingOffset_Min : KernelDataSamplingOffset;
	
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
	#else
	float3 colors[KernelDataCount3x3];
	
	colors[4] = original_color;
	
	colors[0] = GetTexel(	uv,		-KernelDataSamplingOffset,		-KernelDataSamplingOffset		);
	colors[1] = GetTexel(	uv,		0.0f,							-KernelDataSamplingOffset		);
	colors[2] = GetTexel(	uv,		KernelDataSamplingOffset,		-KernelDataSamplingOffset		);
	
	colors[3] = GetTexel(	uv,		-KernelDataSamplingOffset,		0.0f							);
	colors[5] = GetTexel(	uv,		KernelDataSamplingOffset,		0.0f							);
	
	colors[6] = GetTexel(	uv,		-KernelDataSamplingOffset,		KernelDataSamplingOffset		);
	colors[7] = GetTexel(	uv,		0.0f,							KernelDataSamplingOffset		);
	colors[8] = GetTexel(	uv,		KernelDataSamplingOffset,		KernelDataSamplingOffset		);
	#endif
	
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

#ifndef EFFECTLOOP_ENABLED
// trimmed mean単発ver

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
//	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv);
	const bool is_highreso = ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv);
	
	return TrimmedMean(uv, original_color, is_highreso);
}
#elif (EFFECTLOOP_ENABLED > 1)
// trimmed mean複数回適用ver
// 画質は良好だがGPU負荷が高く実行速度が低下する場合がある


inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
	if(EffectLoopCount > EffectLevel)
		return original_color;
	
//	if( (EffectLoopCount > 0) && ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv) )
	if( (EffectLoopCount > 0) && ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv) )
		return original_color;
	
	return TrimmedMean(uv, original_color);
}
#else
// trimmed mean複数回適用ver
// 画質は良好だがGPU負荷が高く実行速度が低下する場合がある

inline float3 ApplyEffect(const float2 uv)
{
	const float3 original_color = GetTexel(uv);
	
	if(RenderMagnification < 2)			// temp
		return original_color;
	
//	const bool is_highreso = (EffectLevel == 0) || ( ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTile_fromUv(uv) );
	const bool is_highreso = (EffectLevel == 0) || ( ( (EffectMode == 1) || (EffectMode == 3) ) && CheckHighResolutionTexel(uv) );
	
	if(EffectLoopCount == 0)
		return TrimmedMean(uv, original_color, is_highreso);
	
	if(is_highreso)
		return original_color;
	
	return TrimmedMean(uv, original_color, false);
}
#endif
