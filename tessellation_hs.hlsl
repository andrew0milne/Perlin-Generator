// Tessellation Hull Shader
// Prepares control points for tessellation

Texture2D heightMap : register(t0);
Texture2D heightMap2 : register(t1);
SamplerState SampleType : register(s0);


cbuffer TessBuffer : register(cb0)
{
	float3 camera_position;
	float heightScale;
	float2 mapSize;
	float2 quadPos;
}

struct InputType
{
    float3 position : POSITION;
	float3 normal : NORMAL;
	float2 tex : TEXCOORD0;
    float4 colour : COLOR;
};

struct ConstantOutputType
{
    float edges[4] : SV_TessFactor;
    float inside[2] : SV_InsideTessFactor;
};

struct OutputType
{
    float3 position : POSITION;
	float3 normal : NORMAL;
    float4 colour : COLOR;

};

//ConstantOutputType PatchConstantFunction(InputPatch<InputType, 3> inputPatch, uint patchId : SV_PrimitiveID)
//{    
//    ConstantOutputType output;
//	
//    // Set the tessellation factors for the three edges of the triangle.
//	output.edges[0] = inside;
//	output.edges[1] = inside;
//	output.edges[2] = inside;
//
//    // Set the tessellation factor for tessallating inside the triangle.
//	output.inside = outside;
//
//    return output;
//}

// Calculates the distance between pos1 and pos
float CalculateDistance(float3 pos1, float3 pos2, float2 texCoord)
{	
	pos2.y = (heightMap.SampleLevel(SampleType, texCoord, 0)) * heightScale;
	
	float d_x = (pos1.x - pos2.x);
	float d_y = (pos1.y - pos2.y);
	float d_z = (pos1.z - pos2.z);

	float distance = (d_x * d_x) + (d_y * d_y) + (d_z * d_z);
	distance = sqrt(distance);

	distance = 64 - distance * 4;

	if (distance > 64)
	{
		distance = 64;
	}
	else if (distance < 2)
	{
		distance = 2;
	}

	return distance;
}

// Scales the texture coordinates to fit in the map array
float2 CalculateTexCoord(float2 uvCoord)
{
	float2 texCoord;

	texCoord.x = uvCoord.x * (1.0f / mapSize.x) - ((quadPos.x / mapSize.x) + (1.0f / mapSize.x));
	texCoord.y = uvCoord.y * (1.0f / mapSize.y) + (quadPos.y / mapSize.y);

	return uvCoord;
}

// Calculates how much to tessellate the input by
ConstantOutputType PatchConstantFunction(InputPatch<InputType, 4> inputPatch, uint patchId : SV_PrimitiveID)
{
	ConstantOutputType output;
	
	float tessFactor;

	float3 midPoint;
	float3 edge1, edge2, edge3, edge4;

	float2 midTex;
	float2 tex1, tex2, tex3, tex4;

	edge1 = inputPatch[0].position + inputPatch[1].position;
	edge1 /= 2;
	tex1 = inputPatch[0].tex + inputPatch[1].tex;
	tex1 /= 2;

	edge2 = inputPatch[1].position + inputPatch[3].position;
	edge2 /= 2;
	tex2 = inputPatch[1].tex + inputPatch[3].tex;
	tex2 /= 2;

	edge3 = inputPatch[3].position + inputPatch[2].position;
	edge3 /= 2;
	tex3 = inputPatch[3].tex + inputPatch[2].tex;
	tex3 /= 2;

	edge4 = inputPatch[0].position + inputPatch[2].position;
	edge4 /= 2;
	tex4 = inputPatch[0].tex + inputPatch[2].tex;
	tex4 /= 2;

	// Set the tessellation factors for the 4 edges of the quad.
	
	tessFactor = CalculateDistance(camera_position, edge1, CalculateTexCoord(tex1));
	output.edges[0] = tessFactor;

	tessFactor = CalculateDistance(camera_position, edge2, CalculateTexCoord(tex2));
	output.edges[1] = tessFactor;

	tessFactor = CalculateDistance(camera_position, edge3, CalculateTexCoord(tex3));
	output.edges[2] = tessFactor;

	tessFactor = CalculateDistance(camera_position, edge4, CalculateTexCoord(tex4));
	output.edges[3] = tessFactor;



	midPoint = inputPatch[0].position + inputPatch[1].position + inputPatch[2].position + inputPatch[3].position;
	midPoint /= 4;
	midTex = inputPatch[0].tex + inputPatch[1].tex + inputPatch[2].tex + inputPatch[3].tex;
	midTex /= 4;

	tessFactor = CalculateDistance(camera_position, midPoint, CalculateTexCoord(midTex));

	// Set the tessellation factor for tessallating inside the quad.
	output.inside[0] = tessFactor;// distances[0];
	output.inside[1] = tessFactor; //distances[1];

	return output;
}
//
//[domain("tri")]
//[partitioning("fractional_even")]
//[outputtopology("triangle_cw")]
//[outputcontrolpoints(3)]
//[patchconstantfunc("PatchConstantFunction")]
//OutputType main(InputPatch<InputType, 3> patch, uint pointId : SV_OutputControlPointID, uint patchId : SV_PrimitiveID)
//{
//    OutputType output;
//
//    // Set the position for this control point as the output position.
//    output.position = patch[pointId].position;
//
//    // Set the input color as the output color.
//    output.colour = patch[pointId].colour;
//
//    return output;
//}

[domain("quad")]
[partitioning("fractional_even")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(4)]
[patchconstantfunc("PatchConstantFunction")]
OutputType main(InputPatch<InputType, 4> patch, uint pointId : SV_OutputControlPointID, uint patchId : SV_PrimitiveID)
{
	OutputType output;

	// Set the position for this control point as the output position.
	output.position = patch[pointId].position;

	output.normal = patch[pointId].normal;

	// Set the input color as the output color.
	output.colour = patch[pointId].colour;

	return output;
}