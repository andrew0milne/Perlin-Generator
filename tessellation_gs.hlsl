// Example geometry shader
// Receives a point and outputs a triangle

Texture2D normalMap : register(t0);
SamplerState SampleType : register(s0);

cbuffer MatrixBuffer : register(cb0)
{
    matrix worldMatrix;
    matrix viewMatrix;
    matrix projectionMatrix;

	matrix lightViewMatrix[2];
	matrix lightProjectionMatrix[2];

	float3 camPos;
	float padding;
};

cbuffer PositionBuffer
{
	static float3 g_positions[4] =
	{
		float3(-1, 1, 0),
		float3(-1, -1, 0),
		float3(1, 1, 0),
		float3(1, -1, 0)
	};
};

struct InputType
{
	float4 position : POSITION;
	float4 depthPosition : TEXCOORD0;
	float3 normal : NORMAL;
	float2 tex : TEXCOORD1;
	float3 lightPos : TEXCOORD2;
	float3 lightPos2 : TEXCOORD3;
};

// pixel input type
struct OutputType
{
	float4 position : SV_POSITION;
	float3 normal : NORMAL;
	float2 tex : TEXCOORD0;
	float4 lightViewPosition : TEXCOORD1;
	float3 lightPos : TEXCOORD2;
	float4 lightViewPosition2 : TEXCOORD3;
	float3 lightPos2 : TEXCOORD4;
	float4 depthPosition : TEXCOORD5;
	float3 viewDirection : TEXCOORD6;
};

// gs function
[maxvertexcount(3)]
void main(triangle InputType input[3], inout TriangleStream<OutputType> triStream)
{
	OutputType output;
	float4 worldPosition;

	float3 p0 = input[0].position.xyz;
	float3 p1 = input[1].position.xyz;
	float3 p2 = input[2].position.xyz;

	float3 edge1 = p1 - p0;
	float3 edge2 = p2 - p0;
	
	float3 normal = cross(edge2, edge1);
	normal = normalize(normal);

	input[0].normal = normal;
	input[1].normal = normal;
	input[2].normal = normal;

	for (int i = 0; i < 3; i++)
	{
			
		// Change the position vector to be 4 units for proper matrix calculations.
		input[i].position.w = 1.0f;

		// Move the vertex away from the point position
		output.position = input[i].position;

		output.lightViewPosition = mul(input[i].position, worldMatrix);
		output.lightViewPosition = mul(output.lightViewPosition, lightViewMatrix[0]);
		output.lightViewPosition = mul(output.lightViewPosition, lightProjectionMatrix[0]);

		output.lightViewPosition2 = mul(input[i].position, worldMatrix);
		output.lightViewPosition2 = mul(output.lightViewPosition2, lightViewMatrix[1]);
		output.lightViewPosition2 = mul(output.lightViewPosition2, lightProjectionMatrix[1]);

		// Calculate the position of the vertex in the world.
		worldPosition = mul(input[i].position.xyz, worldMatrix);
		// Determine the light direction based on the position of the light and the position of the vertex in the world.
		output.lightPos = input[i].lightPos.xyz - worldPosition.xyz;
		// Normalize the light direction vector.
		output.lightPos = normalize(output.lightPos);


		// Determine the light direction based on the position of the light and the position of the vertex in the world.
		output.lightPos2 = input[i].lightPos2.xyz - worldPosition.xyz;
		// Normalize the light direction vector.
		output.lightPos2 = normalize(output.lightPos);

		// Determine the vertix's position in the world
		output.position = mul(output.position, worldMatrix);

		// Determine the cameras view direction
		output.viewDirection = normalize(camPos - output.position.xyz);

		output.position = mul(output.position, viewMatrix);
		output.position = mul(output.position, projectionMatrix);

		// Saves a copy of the positionfor the depth calculations
		output.depthPosition = output.position;

		output.tex = input[i].tex;

		// Determine the noraml relative to the world
		output.normal = mul(input[i].normal, (float3x3)worldMatrix);
		output.normal = normalize(output.normal);

		triStream.Append(output);
	}

	triStream.RestartStrip();

}