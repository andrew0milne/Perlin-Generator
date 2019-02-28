// Colour pixel/fragment shader
// Basic fragment shader outputting a colour

Texture2D shaderTexture : register(t0);
SamplerState SampleType : register(s0);

struct InputType
{
	float4 position : SV_POSITION;
	float2 tex : TEXCOORD0;
};

float4 main(InputType input) : SV_TARGET
{
	float4 colour;

	// Initialize the colour to black.
	colour = float4(0.0f, 0.0f, 0.0f, 0.0f);
	
	colour += shaderTexture.Sample(SampleType, input.tex);
	
	colour.a = 1.0f;
	return colour;

}