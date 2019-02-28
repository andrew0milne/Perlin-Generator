// Tessellation domain shader
// After tessellation the domain shader processes the all the vertices

Texture2D heightMap : register(t0);
Texture2D heightMap2 : register(t1);
SamplerState SampleType : register(s0);

cbuffer mapBuffer : register(cb0)
{
	float2 mapSize;
	float2 quadPos;
	float heightScale;
	float alpha;
	float waterLevel;
	float padding;
};

cbuffer LightBuffer : register(cb1)
{
	float4 diffuseColour[2];
	float4 ambientColour[2];
	float3 lightPosition[2];
	float2 paddingLight;
};

struct ConstantOutputType
{
    float edges[4] : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};

struct InputType
{
    float4 position : POSITION;
	float3 normal : NORMAL;
    float4 colour : COLOR;
};

struct OutputType
{
    float4 position : POSITION;
	float4 depthPosition : TEXCOORD0;
	float3 normal : NORMAL;
	float2 tex : TEXCOORD1;
	float3 lightPos : TEXCOORD2;
	float3 lightPos2 : TEXCOORD3;   
};

float2 CalculateTexCoord(float2 uvCoord)
{
	float2 texCoord;

	texCoord.x = uvCoord.x * (1.0f / mapSize.x) - ((quadPos.x / mapSize.x) + (1.0f / mapSize.x));
	texCoord.y = uvCoord.y * (1.0f / mapSize.y) + (quadPos.y / mapSize.y);

	return texCoord;
}

[domain("quad")]
OutputType main(ConstantOutputType input, float2 uvwCoord : SV_DomainLocation, const OutputPatch<InputType, 4> patch)
{
	
	float3 vertexPosition;
	float3 normalPosition;
	float3 normalFromMap;
	float2 texCoord;

	OutputType output;

	//input.position.w = 1.0f;

	float3 pos0, pos1, pos2, pos3;

	//1------0
	//| *    |
	//|      |
	//3------2

	pos0 = patch[0].position;
	pos1 = patch[1].position;
	pos2 = patch[2].position;
	pos3 = patch[3].position;

	float3 v1 = lerp(pos0, pos1, 1 - uvwCoord.y);
	float3 v2 = lerp(pos2, pos3, 1 - uvwCoord.y);

	vertexPosition = lerp(v1, v2, uvwCoord.x);

	texCoord.x = uvwCoord.x * (1.0f / mapSize.x) - ((quadPos.x / mapSize.x) + (1.0f / mapSize.x));
	texCoord.y = uvwCoord.y * (1.0f / mapSize.y) + (quadPos.y / mapSize.y);

	float map = (heightMap.SampleLevel(SampleType, texCoord, 0));

	if (map < waterLevel)
	{
		map = waterLevel;
	}

	map -= waterLevel;

	vertexPosition.y = map * heightScale;
	
	// Calculate the position of the new vertex against the world, view, and projection matrices.
	output.position = float4(vertexPosition, 1.0f);
	
	output.lightPos = lightPosition[0];
	output.lightPos2 = lightPosition[1];

	output.tex = texCoord;

	output.depthPosition = output.position;


	return output;
}

