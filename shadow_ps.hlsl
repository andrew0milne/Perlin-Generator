
Texture2D shaderTexture : register(t0);
Texture2D depthMapTexture : register(t1);
Texture2D depthMapTexture2 : register(t2);

SamplerState SampleTypeWrap  : register(s0);
SamplerState SampleTypeClamp : register(s1);

cbuffer LightBuffer : register(cb0)
{
	float4 ambientColor[2];
	float4 diffuseColor[2];
};

struct InputType
{
    float4 position : SV_POSITION;
    float2 tex : TEXCOORD0;
	float3 normal : NORMAL;
    float4 lightViewPosition : TEXCOORD1;
	float3 lightPos : TEXCOORD2;
	float4 lightViewPosition2 : TEXCOORD3;
	float3 lightPos2 : TEXCOORD4;
};

float CalculateDistance(float3 pos1, float3 pos2)
{
	float d_x = (pos1.x - pos2.x);
	float d_y = (pos1.y - pos2.y);
	float d_z = (pos1.z - pos2.z);

	float distance = (d_x * d_x) + (d_y * d_y) + (d_z * d_z);
	distance = sqrt(distance);
	
	return distance;
}

float4 GetColour(InputType input, float4 ambientColor, float4 diffuseColor, float4 lvp, float3 pos, Texture2D tex, float range)
{
	float bias;
	float4 color;
	float4 projectTexCoord = (0.0f, 0.0f, 0.0f, 0.0f);
	float depthValue = 1.0f;
	float lightDepthValue;
	float lightIntensity;
	float4 textureColor;

	//float range = 50.0f;
	float distance;

	distance = CalculateDistance(lvp.xyz, pos);

	if (distance <= range)
	{
		// Set the bias value for fixing the floating point precision issues.
		bias = 0.0001f;

		// Set the default output color to the ambient light value for all pixels.
		color = ambientColor;

		// Calculate projected coordinates, then into UV range
		projectTexCoord.xyz = lvp.xyz / lvp.z;

		// Calculate the projected texture coordinates.
		projectTexCoord.x = (projectTexCoord.x / 2.0f) + 0.5f;
		projectTexCoord.y = (-projectTexCoord.y / 2.0f) + 0.5f;

	
		//// Determine if the projected coordinates are in the 0 to 1 range.  If so then this pixel is in the view of the light.
		if ((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y))
		{
			// Sample the shadow map depth value from the depth texture using the sampler at the projected texture coordinate location.
			depthValue = tex.Sample(SampleTypeClamp, projectTexCoord).r;
			//textureColor = tex.Sample(SampleTypeClamp, projectTexCoord);

			// Calculate the depth of the light.
			lightDepthValue = lvp.z / lvp.w;

			// Subtract the bias from the lightDepthValue.
			lightDepthValue = lightDepthValue - bias;

			// Compare the depth of the shadow map value and the depth of the light to determine whether to shadow or to light this pixel.
			// If the light is in front of the object then light the pixel, if not then shadow this pixel since an object (occluder) is casting a shadow on it.
			if (lightDepthValue < depthValue)
			{
				// Calculate the amount of light on this pixel.
				lightIntensity = saturate(dot(input.normal, pos));

				lightIntensity *= (1 - (distance / range));

				if (lightIntensity > 0.0f)
				{
					// Determine the final diffuse color based on the diffuse color and the amount of light intensity.
					color += (diffuseColor * lightIntensity);

					// Saturate the final light color.
					color = saturate(color);
				}
			}
		}
	}

	return float4(depthValue, depthValue, depthValue, 1.0f);
	return color;
}

float4 main(InputType input) : SV_TARGET
{
	float4 color;
    float4 textureColor;

	//input.lightViewPosition = float4(1.0f, 1.0f, 1.0f, 1.0f);

	color = GetColour(input, ambientColor[0], diffuseColor[0], input.lightViewPosition, input.lightPos, depthMapTexture, 100.0f);
	color += GetColour(input, ambientColor[1], diffuseColor[1], input.lightViewPosition2, input.lightPos2, depthMapTexture2, 40.0f);

	
	// Sample the pixel color from the texture using the sampler at this texture coordinate location.
	textureColor = shaderTexture.Sample(SampleTypeWrap, input.tex);

	// Combine the light and texture color.
	//color = color * textureColor;
	
	//return depthColour;

    return color;
}