// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


#define MAX_EFFECTLEVEL 3
#define MAX_EFFECTMODE 3
#define MAX_EFFECTLOOP 0

#define DEFAULT_MAIN_FUNC_DISABLED


#include "PixelShader.hlsli"


//#define POSITION_CHECKER_ENABLED


//----------------------------------------------------------------------

float4 main(const float2 uv : TEXCOORD) : COLOR0
{
	const float3 original_color = GetTexel_Raw(uv);
	const PositionInfo position = GetPositionInfo(uv);
	
	float3 color = clamp( GetColorIntensity(original_color) - 0.5f, 0.0f, 1.0f );		// グレイスケール化
	
	#ifndef POSITION_CHECKER_ENABLED
	// highreso flag checker
	switch(EffectMode)
	{
		case 3:
			color = GetTexel_Raw( TilePositionToUv(position.Tile), position.Local );
			break;
		
		case 2:
//			if( CheckHighResolutionTile(position.Tile) )
			if( CheckHighResolutionTile_fromUv(uv) )
				color.g += 1.0f;
			
			break;
		
		case 1:
			if( CheckHighResolutionTexel(uv) )
				color.r += 1.0f;
			
//			else if( CheckHighResolutionTile(position.Tile) )
			else if( CheckHighResolutionTile_fromUv(uv) )
				color.g += 1.0f;
			
			break;
		
		default:
			if( CheckHighResolutionTexel(uv) )
				color.r += 1.0f;
			
			break;
	}
	#else
	switch(EffectMode)
	{
		case 1:
			// converted position checker 2
			float3 converted_color = (float3)0;
			
			switch(EffectLevel)
			{
				case 3:
//					converted_color = GetTexel( TilePositionToUv(position.Tile, position.Local) );
					converted_color = GetTexel( TilePositionToUv(position.Tile), position.Local );
					break;
				
				case 2:
					converted_color = GetTexel( TilePositionToUv(position.Tile, position.Local) );
					break;
				
				case 1:
					converted_color = GetTexel( GlobalPositionToUv(position.Global) );
					break;
				
				default:
					converted_color = GetTexel_Raw( GlobalPositionToUv(position.Global) );
					break;
			}
			
			if( NotEquals(converted_color, original_color) )
				color.r += 1.0f;
			
			break;
		
		default:
			// converted position checker
			static const float2 threshold = TextureSamplingInterval / 1000.0f;
			
//			const float2 converted_uv = GlobalPositionToUv(position.Global);
			const float2 converted_uv = TilePositionToUv(position.Tile, position.Local);
			const float2 delta = converted_uv - uv;
			
			switch(EffectLevel)
			{
				case 3:
					if(delta.x > 0.0f)
						color.r += 1.0f;
					
					if(delta.y > 0.0f)
						color.g += 1.0f;
					
					break;
				
				case 2:
					if(delta.x < 0.0f)
						color.r += 1.0f;
					
					if(delta.y < 0.0f)
						color.g += 1.0f;
					
					break;
				
				case 1:
					if(delta.x > threshold.x)
						color.r += 1.0f;
					
					if(delta.y > threshold.y)
						color.g += 1.0f;
					
					break;
				
				default:
					if(delta.x < -threshold.x)
						color.r += 1.0f;
					
					if(delta.y < -threshold.y)
						color.g += 1.0f;
					
					if( all(delta >= -threshold) && all(delta <= threshold) )
						color.b += 0.5f;
					break;
			}
			break;
	}
	#endif
	
	
	color = clamp(color, 0.0f, 1.0f);
	
	return float4(color, 1.0f);
}

