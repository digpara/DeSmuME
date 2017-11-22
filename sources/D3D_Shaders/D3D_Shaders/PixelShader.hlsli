// Post-Processing Shader for DeSmuME X432R Direct3D DisplayMethod
// Shader Model 3.0
// author: yolky-nine


#ifndef PIXELSHADERHEADER_HLSL_INCLUDED
#define PIXELSHADERHEADER_HLSL_INCLUDED


//------------------------------------------------------------------------------------------

//#define MIN_RENDER_MAGNIFICATION 1
#define MIN_RENDER_MAGNIFICATION 2			// temp
#define MAX_RENDER_MAGNIFICATION 4


#ifndef MAX_EFFECTLEVEL
#define MAX_EFFECTLEVEL 3

#elif (MAX_EFFECTLEVEL < 0)
#undef MAX_EFFECTLEVEL
#define MAX_EFFECTLEVEL 0

#elif (MAX_EFFECTLEVEL > 3)
#undef MAX_EFFECTLEVEL
#define MAX_EFFECTLEVEL 3
#endif


#ifndef MAX_EFFECTMODE
#define MAX_EFFECTMODE 3

#elif (MAX_EFFECTMODE < 0)
#undef MAX_EFFECTMODE
#define MAX_EFFECTMODE 0

#elif (MAX_EFFECTMODE > 3)
#undef MAX_EFFECTMODE
#define MAX_EFFECTMODE 3
#endif


#ifndef MAX_EFFECTLOOP
#define MAX_EFFECTLOOP 0

#elif (MAX_EFFECTLOOP < 0)
#undef MAX_EFFECTLOOP
#define MAX_EFFECTLOOP 0

#elif (MAX_EFFECTLOOP > 5)
#undef MAX_EFFECTLOOP
#define MAX_EFFECTLOOP 5
#endif


//------------------------------------------------------------------------------------------

/*
struct InputParams
{
//	float3 Position : VPOS;
	float2 TexCoord : TEXCOORD;
//	float4 Diffuse : COLOR;
};
*/


// texture
uniform sampler2D TextureSampler_Raw : register(s0);			// NDS screen raw data + point filter
uniform sampler2D TextureSampler_Filtered : register(s1);		// post-processed offscreen buffer + linear filter

inline float3 GetTexel(const float2 uv)
{
	return tex2D(TextureSampler_Filtered, uv).rgb;
}

inline float3 GetTexel_Raw(const float2 uv)
{
	return tex2D(TextureSampler_Raw, uv).rgb;
}


// constant
uniform float4 EffectParams : register(c0);

static const int RenderMagnification = clamp( (int)EffectParams[0], MIN_RENDER_MAGNIFICATION, MAX_RENDER_MAGNIFICATION );
static const int EffectLevel = clamp( (int)EffectParams[1], 0, MAX_EFFECTLEVEL );
static const int EffectMode = clamp( (int)EffectParams[2], 0, MAX_EFFECTMODE );
static const int EffectLoopCount = max( (int)EffectParams[3], 0 );


//------------------------------------------------------------------------------------------

#ifndef DEFAULT_MAIN_FUNC_DISABLED
inline float3 ApplyEffect(const float2 uv);


float4 main(const float2 uv : TEXCOORD) : COLOR0
{
	return ( float4( (EffectLoopCount <= MAX_EFFECTLOOP) ? ApplyEffect(uv) : GetTexel(uv), 1.0f ) );
}
#endif


//------------------------------------------------------------------------------------------

static const float Pi = 3.14159265f;


static const float2 TextureSize = { 256.0f * (float)RenderMagnification, 192.0f * 2.0f * (float)RenderMagnification };
static const float2 TextureSize_LowResolution = {256.0f, 192.0f * 2.0f};

static const float2 TextureSamplingInterval = 1.0f / TextureSize;


inline float3 GetTexel(const float2 uv, const float2 offset)
{
	return GetTexel( uv + (offset * TextureSamplingInterval) );
}

inline float3 GetTexel_Raw(const float2 uv, const float2 offset)
{
	return GetTexel_Raw( uv + (offset * TextureSamplingInterval) );
}

inline float3 GetTexel(const float2 uv, const float u_offset, const float v_offset)
{
	return GetTexel( uv, float2(u_offset, v_offset) );
}

inline float3 GetTexel_Raw(const float2 uv, const float u_offset, const float v_offset)
{
	return GetTexel_Raw( uv, float2(u_offset, v_offset) );
}


inline float GetColorIntensity(const float3 color)
{
//	return ( (color.r + color.g + color.b) / 3.0f );
	return ( (color.r * 0.3f) + (color.g * 0.6f) + (color.b * 0.1f) );
}


inline bool Equals(const float2 values1, const float2 values2)
{
	return all(values1 == values2);
}

inline bool Equals(const float3 values1, const float3 values2)
{
	return all(values1 == values2);
}

inline bool Equals(const float4 values1, const float4 values2)
{
	return all(values1 == values2);
}

inline bool NotEquals(const float2 values1, const float2 values2)
{
	return any(values1 != values2);
}

inline bool NotEquals(const float3 values1, const float3 values2)
{
	return any(values1 != values2);
}

inline bool NotEquals(const float4 values1, const float4 values2)
{
	return any(values1 != values2);
}


//------------------------------------------------------------------------------------------

static const int KernelDataCount3x3 = 9;
static const int KernelCenterIndex3x3 = 4;


static const int TileDataCount = RenderMagnification * RenderMagnification;
static const int TileDataCountX2 = 4;
static const int TileDataCountX3 = 9;
static const int TileDataCountX4 = 16;

static const int TileLocal_MaxIndex = RenderMagnification - 1;

static const float2 TileSize = RenderMagnification;
static const float2 TileCenterPosition = (float)TileLocal_MaxIndex * 0.5f;


struct PositionInfo
{
	float2 TexCoord;		// texel position
	float2 Global;			// pixel position
	float2 Tile;			// pixel position in low-resolution screen
	float2 Local;			// pixel position in tile
};

inline PositionInfo GetPositionInfo(const float2 uv)
{
	PositionInfo result;
	
	result.TexCoord = uv;
	result.Global = floor(uv * TextureSize);
	result.Tile = floor( uv * float2(256.0f, 192.0f * 2.0f) );
	result.Local = result.Global % (float)RenderMagnification;
	
	return result;
}

inline float2 UvToGlobalPosition(const float2 uv)
{
	return floor(uv * TextureSize);
}

inline float2 UvToTilePosition(const float2 uv)
{
	return floor( uv * float2(256.0f, 192.0f * 2.0f) );
}

inline float2 UvToLocalPosition(const float2 uv)
{
	return ( floor(uv * TextureSize) % (float)RenderMagnification );
}

inline float2 GlobalPositionToUv(const float2 global_position)
{
	return ( ( global_position + float2(0.5f, 0.5f) ) / TextureSize );
}

inline float2 TilePositionToUv(const float2 tile_position)
{
	return GlobalPositionToUv( tile_position * (float)RenderMagnification );
}

inline float2 TilePositionToUv(const float2 tile_position, const float2 local)
{
	return GlobalPositionToUv( ( tile_position * (float)RenderMagnification ) + local );
}

/*
inline bool IsTileEdge(const int2 local_position)
{
	return ( (local_position.x == 0) || (local_position.x == TileLocal_MaxIndex) || (local_position.y == 0) || (local_position.y == TileLocal_MaxIndex) );
}

inline bool IsTileCorner(const int2 local_position)
{
	return ( ( (local_position.x == 0) || (local_position.x == TileLocal_MaxIndex) ) && ( (local_position.y == 0) || (local_position.y == TileLocal_MaxIndex) ) );
}


float3 GetAveragedTileColor(float2 tile_position)
{
	tile_position = TilePositionToUv(tile_position);
	
	switch(RenderMagnification)
	{
		case 4:
			return ( ( GetTexel(tile_position, 0.5f, 0.5f) + GetTexel(tile_position, 2.5f, 0.5f) + GetTexel(tile_position, 0.5f, 2.5f) + GetTexel(tile_position, 2.5f, 2.5f) ) / 4.0f );
		
		case 3:
			return ( ( GetTexel(tile_position, 0.5f, 0.5f) + GetTexel(tile_position, 1.5f, 0.5f) + GetTexel(tile_position, 0.5f, 1.5f) + GetTexel(tile_position, 1.5f, 1.5f) ) / 4.0f );
		
		default:
			return GetTexel(tile_position, 0.5f, 0.5f);
	}
}

inline float3 GetAveragedTileColor(const float2 tile_position, const float2 offset)
{
	return GetAveragedTileColor(tile_position + offset);
}

inline float3 GetAveragedTileColor(const float2 tile_position, const float x_offset, const float y_offset)
{
	return GetAveragedTileColor( tile_position + float2(x_offset, y_offset) );
}
*/

float3 GetTileColor_fromNearestTexel(const float2 tile_position, const float2 offset)
{
	return GetTexel( TilePositionToUv(tile_position), ( TileCenterPosition + (offset * TileSize) ) - ( sign(offset) * ( TileCenterPosition - float2(0.5f, 0.5f) ) ) );
}

float3 GetTileColor_fromNearestTexel(const float2 tile_position, const float x_offset, const float y_offset)
{
	return GetTileColor_fromNearestTexel( tile_position, float2(x_offset, y_offset) );
}


float3 GetTileColor_fromNearestTexel_Raw(const float2 tile_position, const float2 offset)
{
	return GetTexel_Raw( TilePositionToUv(tile_position), ( TileCenterPosition + (offset * TileSize) ) - ( sign(offset) * ( TileCenterPosition - float2(0.5f, 0.5f) ) ) );
}

float3 GetTileColor_fromNearestTexel_Raw(const float2 tile_position, const float x_offset, const float y_offset)
{
	return GetTileColor_fromNearestTexel_Raw( tile_position, float2(x_offset, y_offset) );
}


//------------------------------------------------------------------------------------------

static const float PresetHighResolutionCheckOffset[3] =
{
//	0.95f,		1.45f,		1.95f		// magnification 2, 3, 4
//	1.0f,		1.5f,		2.0f
//	1.0f,		1.3f,		1.6f
	
	0.95f,		1.45f,		2.45f
};

static const float HighResolutionCheckOffset = PresetHighResolutionCheckOffset[RenderMagnification - 2];		// RenderMafnificationによってサンプリング位置を変える


#if 1
bool CheckHighResolutionTexel(const float2 uv)
{
	const float3 center_color = GetTexel_Raw(uv);
	
	#if 1
	const bool is_uneven_00 = NotEquals( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		-HighResolutionCheckOffset		), center_color );
	const bool is_uneven_01 = NotEquals( GetTexel_Raw(		uv,		0,								-HighResolutionCheckOffset		), center_color );
	const bool is_uneven_02 = NotEquals( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		-HighResolutionCheckOffset		), center_color );
	
	const bool is_uneven_10 = NotEquals( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		0								), center_color );
	const bool is_uneven_12 = NotEquals( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		0								), center_color );
	
	const bool is_uneven_20 = NotEquals( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		HighResolutionCheckOffset		), center_color );
	const bool is_uneven_21 = NotEquals( GetTexel_Raw(		uv,		0,								HighResolutionCheckOffset		), center_color );
	const bool is_uneven_22 = NotEquals( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		HighResolutionCheckOffset		), center_color );
	
	return
	(
		(is_uneven_00 || is_uneven_01 || is_uneven_10) &&		// left top
		(is_uneven_01 || is_uneven_02 || is_uneven_12) &&		// right top
		(is_uneven_10 || is_uneven_20 || is_uneven_21) &&		// left bottom
		(is_uneven_12 || is_uneven_21 || is_uneven_22)			// right bottom
	);
	#else
	const bool is_uneven_00 = NotEquals( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		-HighResolutionCheckOffset		), center_color );
	const bool is_uneven_02 = NotEquals( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		-HighResolutionCheckOffset		), center_color );
	
	const bool is_uneven_20 = NotEquals( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		HighResolutionCheckOffset		), center_color );
	const bool is_uneven_22 = NotEquals( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		HighResolutionCheckOffset		), center_color );
	
	return (is_uneven_00 && is_uneven_02 && is_uneven_20 && is_uneven_22);
	#endif
}


bool CheckHighResolutionTile(float2 tile_position)
{
	tile_position = TilePositionToUv(tile_position);
	
	const float3 color_lefttop = GetTexel_Raw(tile_position);
	const float3 color_righttop = GetTexel_Raw(tile_position, TileLocal_MaxIndex, 0);
	const float3 color_leftbottom = GetTexel_Raw(tile_position, 0, TileLocal_MaxIndex);
	const float3 color_rightbottom = GetTexel_Raw(tile_position, TileLocal_MaxIndex, TileLocal_MaxIndex);
	
	return ( NotEquals(color_lefttop, color_rightbottom) || NotEquals(color_lefttop, color_righttop) || NotEquals(color_leftbottom, color_rightbottom) );
}
#else
//static const float3 HighResolutionCheckThreshold = 0.05f;
static const float3 HighResolutionCheckThreshold = 0.01f;
//static const float3 HighResolutionCheckThreshold = 0.005f;
//static const float3 HighResolutionCheckThreshold = 0.004f;			// 0.0039f = (1 / 256)

bool CheckHighResolutionTexel(const float2 uv)
{
	const float3 center_color = GetTexel_Raw(uv);
	
	#if 0
	const bool is_uneven_00 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		-HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_01 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		0,								-HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_02 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		-HighResolutionCheckOffset		) - center_color ) ) );
	
	const bool is_uneven_10 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		0								) - center_color ) ) );
	const bool is_uneven_12 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		0								) - center_color ) ) );
	
	const bool is_uneven_20 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_21 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		0,								HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_22 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		HighResolutionCheckOffset		) - center_color ) ) );
	
	return
	(
		(is_uneven_00 || is_uneven_01 || is_uneven_10) &&		// left top
		(is_uneven_01 || is_uneven_02 || is_uneven_12) &&		// right top
		(is_uneven_10 || is_uneven_20 || is_uneven_21) &&		// left bottom
		(is_uneven_12 || is_uneven_21 || is_uneven_22)			// right bottom
	);
	#else
	const bool is_uneven_00 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		-HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_02 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		-HighResolutionCheckOffset		) - center_color ) ) );
	
	const bool is_uneven_20 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		-HighResolutionCheckOffset,		HighResolutionCheckOffset		) - center_color ) ) );
	const bool is_uneven_22 = any( step( HighResolutionCheckThreshold, abs( GetTexel_Raw(		uv,		HighResolutionCheckOffset,		HighResolutionCheckOffset		) - center_color ) ) );
	
	return (is_uneven_00 && is_uneven_02 && is_uneven_20 && is_uneven_22);
	#endif
}


bool CheckHighResolutionTile(float2 tile_position)
{
	tile_position = TilePositionToUv(tile_position);
	
	const float3 color_lefttop = GetTexel_Raw(tile_position);
	const float3 color_righttop = GetTexel_Raw(tile_position, TileLocal_MaxIndex, 0);
	const float3 color_leftbottom = GetTexel_Raw(tile_position, 0, TileLocal_MaxIndex);
	const float3 color_rightbottom = GetTexel_Raw(tile_position, TileLocal_MaxIndex, TileLocal_MaxIndex);
	
	return
	(
		any( step( HighResolutionCheckThreshold, abs(color_lefttop - color_rightbottom) ) ) ||
		any( step( HighResolutionCheckThreshold, abs(color_lefttop - color_righttop) ) ) ||
		any( step( HighResolutionCheckThreshold, abs(color_leftbottom - color_rightbottom) ) )
	);
}
#endif

inline bool CheckHighResolutionTile_fromUv(const float2 uv)
{
	return CheckHighResolutionTile( UvToTilePosition(uv) );
}


#endif
