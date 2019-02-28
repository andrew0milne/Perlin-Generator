// Tessellation pixel shader
// Output colour passed to stage.

Texture2D shaderTexture : register(t0);
Texture2D depthMapTexture : register(t1);
Texture2D depthMapTexture2 : register(t2);
Texture2D grassTexture : register(t3);
Texture2D rockTexture : register(t4);
Texture2D heightMap : register(t5);
Texture2D riverMap : register(t6);

SamplerState SampleTypeWrap : register(s0);
SamplerState SampleTypeClamp : register(s1);

cbuffer depthONBuffer : register(cb0)
{
	float renderState;
	float waterLevel;
	float heightLevel;
	float padding;
	float3 camPos;
	float padding2;
}

cbuffer LightBuffer : register(cb1)
{
	float4 diffuseColour[2];
	float4 ambientColour[2];
	float3 lightPosition[2];
	float lightsOn;
	float paddingLight;
};

struct InputType
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

// Returns the distance between pos1 and pos2
float CalculateDistance(float3 pos1, float3 pos2)
{
	float d_x = (pos1.x - pos2.x);
	float d_y = (pos1.y - pos2.y);
	float d_z = (pos1.z - pos2.z);

	float distance = (d_x * d_x) + (d_y * d_y) + (d_z * d_z);
	distance = sqrt(distance);

	return distance;
}

// Calculates the lighting values
float4 GetColour(InputType input, float4 ambientColour, float4 diffuseColour, float4 lvp, float3 pos, Texture2D dTex, float range)
{
	float bias;
	float4 colour;
	float4 projectTexCoord = (0.0f, 0.0f, 0.0f, 0.0f);
	float depthValue = 1.0f;
	float lightDepthValue;
	float lightIntensity;
	float4 textureColour;

	float distance = CalculateDistance(lvp.xyz, pos);

	if (distance <= range)
	{

		// Set the bias value for fixing the floating point precision issues.
		bias = 0.0001f;

		// Set the default output color to the ambient light value for all pixels.
		colour = ambientColour;

		// Calculate projected coordinates, then into UV range
		projectTexCoord.xyz = lvp.xyz / lvp.z;

		// Calculate the projected texture coordinates.
		projectTexCoord.x = (projectTexCoord.x / 2.0f) + 0.5f;
		projectTexCoord.y = (-projectTexCoord.y / 2.0f) + 0.5f;


		// Determine if the projected coordinates are in the 0 to 1 range.  If so then this pixel is in the view of the light.
		if ((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y))
		{
			// Sample the shadow map depth value from the depth texture using the sampler at the projected texture coordinate location.		
			depthValue = dTex.Sample(SampleTypeClamp, projectTexCoord).r;

			// Calculate the depth of the light.
			lightDepthValue = lvp.z / lvp.w;

			// Subtract the bias from the lightDepthValue.
			lightDepthValue = lightDepthValue - bias;

			// Compare the depth of the shadow map value and the depth of the light to determine whether to shadow or to light this pixel.
			// If the light is in front of the object then light the pixel, if not then shadow this pixel since an object (occluder) is casting a shadow on it.
			// This has been removed as it looks terrible
			if (true)
			{
				// Calculate the amount of light on this pixel.
				lightIntensity = saturate(dot(input.normal, pos));

				lightIntensity *= (1 - (distance / range));

				if (lightIntensity > 0.0f)
				{
					// Determine the final diffuse color based on the diffuse color and the amount of light intensity.
					colour += (diffuseColour * lightIntensity);

					// Saturate the final light color.
					colour = saturate(colour);
				}
			}
		}
		else
		{
			// Calculate the amount of light on this pixel.
			lightIntensity = saturate(dot(input.normal, pos));

			lightIntensity *= (1 - (distance / range));

			if (lightIntensity > 0.0f)
			{
				// Determine the final diffuse color based on the diffuse color and the amount of light intensity.
				colour += (diffuseColour * lightIntensity);

				// Saturate the final light color.
				colour = saturate(colour);
			}
		}
	}
    return colour;
	
	//depthValue is the shadow
	//lightDepthValue is depth from light
}

float4 main(InputType input) : SV_TARGET
{
	float4 textureColour;
	float4 colour;
	float depthValue;

	float nX, nY, nZ;

	float dotP = dot(input.normal, float4(0.0f, 1.0f, 0.0f, 1.0f));

	float angle = acos(dotP);

	float minDist = 5.0f;
	float maxDist = 25.0f;

	float4 grass = float4(0.1f, 0.5f, 0.0f, 1.0f);
	float4 rock = float4(0.5f, 0.5f, 0.5f, 1.0f);
	float4 sand = float4(0.9f, 0.8f, 0.48f, 1.0f);
	float4 shallowWater = float4(0.0f, 0.3f, 1.0f, 1.0f);
	float4 height = heightMap.Sample(SampleTypeWrap, input.tex);
	float4 riverTex = riverMap.Sample(SampleTypeWrap, input.tex);

	float2 offsetTex;
	offsetTex.x = input.tex.y;
	offsetTex.y = input.tex.x;
	float4 offset = heightMap.Sample(SampleTypeWrap, offsetTex);

	// Calculated the height value, height map relative to water level, and then scaled input height level
	float heightValue = (height.x - waterLevel + 0.2f) * heightLevel;	
	if (heightValue > 1.0f)
	{
		heightValue = 1.0f;
	}
	
	// Terrain colour based on height, and steepness respectivly
	float4 heightTex = saturate((grass * (1 - heightValue)) + (heightValue  * rock));
	float4 terrainTex = saturate((grass * (1 - angle)) + (angle  * heightTex));

	// Blending between heightTex and terrainTex, weighted towards heightTex
	terrainTex = ((terrainTex * 0.5f) + heightTex)/1.5f;

	// Beaches & riverbanks
	if (height.x > waterLevel && 
		height.x < waterLevel + ((offset.x / heightLevel) / 20.0f) + 0.01 ||
		riverTex.x - (pow(height.x, 2.5f) * heightLevel) >= 0.6f - waterLevel)
	{
		terrainTex = sand;
	}
	
	// Colours the rivers	
	if(riverTex.x - pow(height.x, 1.5) >= 0.69f - waterLevel ||
		riverTex.x >= (0.76f + (height.x)/20.0f - waterLevel/10.0f))
	{
		terrainTex = shallowWater;
	}
	
	// Colours the water
	if (height.x <= waterLevel)
	{
		// Calculates the green value of the water, depending on the 	
		float green = (height.x - (waterLevel - 0.2f)) * 2.0f;
		green = floor(green * 10.0f) / 10.0f;

		float blue = 1 + green;		
		// Makes the water not too dark
		if (blue < 0.8)
		{
			blue = 0.8f;
		}

		terrainTex = float4(0.0f, green, blue, 1.0f);
	}

	switch (renderState)
	{
	case 0.0f:
	{
	
		colour = GetColour(input, ambientColour[0], diffuseColour[0], input.lightViewPosition, input.lightPos, depthMapTexture, 40.0f);
		colour += GetColour(input, ambientColour[1], diffuseColour[1], input.lightViewPosition2, input.lightPos2, depthMapTexture2, 100.0f);

		colour = colour * terrainTex;

		return colour;
	}
	case 1.0f:
	{
		depthValue = (input.depthPosition.z / input.depthPosition.w);

		float4 depthColour = float4(depthValue, depthValue, depthValue, 1.0f);

		return depthColour;
	}	
	case 2.0f:
	{
		return terrainTex;
	}
	}

	return float4(1.0f, 1.0f, 0.0f, 1.0f);
}