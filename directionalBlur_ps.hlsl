Texture2D shaderTexture : register(t0);
Texture2D depthTexture : register(t1);
SamplerState SampleType : register(s0);

cbuffer ScreenSizeBuffer : register(cb0)
{
	float screenWidth;
	float screenHeight;
	float blurAngle;
	float blurAmount;
	float depthBlur;
	float3 camPos;
};

struct InputType
{
	float4 position : SV_POSITION;
	float4 depthPosition : TEXCOORD0;
	float2 tex : TEXCOORD1;
};

float CalculateDistance(float2 pos1, float2 pos2)
{
	float d_x = (pos1.x - pos2.x);
	float d_y = (pos1.y - pos2.y);

	float distance = (d_x * d_x) + (d_y * d_y);
	distance = sqrt(distance);

	return distance;
}

float CalculateWeight(float x, float xMax)
{
	const float PI = 3.14159;
	const float  E = 2.71828;
	 
	float varience = E / 2.0f;

	float power = -1.0f * (((x*x) / 2) / 2 * varience);

	float weight = (1 / (sqrt(2 * PI * varience)));

	weight = weight * pow(E, power);

	return weight;
}

float4 main(InputType input) : SV_TARGET
{
    float weight;
	float depthValue = 1.0f;
    float4 colour;
	const float PI = 3.14159;
	float2 texCoord;

	// Initialize the colour to black.
	colour = float4(0.0f, 0.0f, 0.0f, 0.0f);

	int xMax = 10;

	float angle = blurAngle * (PI / 180.0f);

	if (depthBlur == 1.0f)
	{
		depthValue = depthTexture.Sample(SampleType, input.tex);
		depthValue *= depthValue;
	}

	// Determine the floating point size of a texel for a screen with this specific width.
	float texelSizeWidth = (1.0f / screenWidth) * cos(angle) * blurAmount * depthValue;
	float texelSizeHeight = (1.0f / screenHeight) * sin(angle) * blurAmount * depthValue;

	for (int i = -xMax; i < xMax + 1; i++)
	{
		// Create UV coordinates for the pixel and its xMax horizontal neighbors on either side.
		texCoord = input.tex + float2(texelSizeWidth * i, texelSizeHeight * i);

		weight = CalculateWeight(i, xMax);
		colour += shaderTexture.Sample(SampleType, texCoord) * weight;
	}

	// Set the alpha channel to one.
    colour.a = 1.0f;
	
    return colour;
}
