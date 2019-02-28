/* 
	This program can be used in conjunction with the shaders program, which displays the outputs

	Procedural height map generator
	Uses Perlin noise to create a height map
	Can make the map an island, and generate rivers
	Saves the height map, and the river map, to a .png

	Written By Andrew Milne
	Last Updated: 26/04/2018
*/

#ifndef __wtypes_h__
#include <wtypes.h>
#endif

#ifndef __WINDEF_
#include <windef.h>
#endif

#include "PerlinNoiseClass.h"
#include <Windows.h>
#include <iostream>
#include <time.h>
#include <stdlib.h>
#include <vector>
#include <list>
#include <random>

#include "GdiplusHeaderFunction.h"
#include <gdiplus.h>

using namespace Gdiplus;
using namespace std;

#pragma comment (lib,"Gdiplus.lib")

struct Vector2
{
	int x = 0;
	int y = 0;
};

struct Node
{
	int x = 0;
	int y = 0;
	float height;

	std::vector<Node*> neighbours;
};

// Gets the perlin noise value at x, y, with various modifiers
float FBM(PerlinNoiseClass p, float x, float y, float ampl, float freq, float pers, float lacu, int oct, int ridged)
{
	float amplitude = ampl;
	float frequency = freq;

	float persistance = pers;
	float lacunarity = lacu;

	int octaves = oct;

	float num = 0.0f;
	float vec[2];
	
	float sum = 0.0f;

	// Based off of http://flafla2.github.io/2014/08/09/perlinnoise.html
	 
	for (int i = 0; i < octaves; i++)
	{	
		vec[0] = x * frequency;
		vec[1] = y * frequency;

		num = p.noise2(vec);

		sum += amplitude * num;

		amplitude *= persistance;
		frequency *= lacunarity;
	}

	switch (ridged)
	{
	case 0:
		return sum;
	case 1:
		return abs(sum);
	case 2:
		return 1 - abs(sum);
	}

	//return sum;// 1 - abs(sum);
}

// Makes the map into an island, using the equation of a circle
float islandify(float xTarget, float yTarget, float xNum, float yNum, float maxDist)
{	
	// Manhatan distance between (xTarget, yTarget) and (xNum, yNum)
	float dist = sqrtf(pow((xTarget) - xNum, 2) + pow((yTarget) - yNum, 2));

	// Stops the concentric rings
	if (dist > maxDist)
	{ 
		dist = maxDist;
	}

	// Convert distance to a value between 0 and 90
	float toNinety = (dist/maxDist) * 90.0f;
	// Convert this to radiens
	float toRadien = (toNinety * 3.14f) / 180;
	// Circle stuff
	float convert = cos(sin(toRadien)) * 2.0f;
	
	return convert - 1.0f;
}

// Initialises a float** array to xSize by ySize, and sets all values to 0.0f
float**  InitGrid(int xSize, int ySize)
{
	float** grid = new float*[ySize];

	for (int i = 0; i < ySize; ++i)
	{
		grid[i] = new float[xSize];
	}

	for (int i = 0; i < xSize; i++)
	{
		for (int j = 0; j < ySize; j++)
		{
			grid[j][i] = 0.0f;
		}
	}
	return grid;
}

// Creatses and initialises an array of Nodes, to be xSize by ySize and sets the height from map
Node** InitNeighbours(int xSize, int ySize, float** map)
{
	// Initialises the an array of Nodes
	Node** nodeMap = new Node*[ySize];
	for (int i = 0; i < ySize; ++i)
	{
		nodeMap[i] = new Node[xSize];
	}
	for (int i = 0; i < xSize; i++)
	{
		for (int j = 0; j < ySize; j++)
		{
			Node tempNode;
			tempNode.x = i;
			tempNode.y = j;
			tempNode.height = map[j][i];
			nodeMap[j][i] = tempNode;
		}
	}
	
	// Gives each node a reference to their Moore neighbourhood
	for (int x = 0; x < 500; x++)
	{
		for (int y = 0; y < 500; y++)
		{
			for (int i = -1; i <= 1; i++)
			{
				for (int j = -1; j <= 1; j++)
				{
					// If the neighbour is within the map
					if ((x + i >= 0 && y + j >= 0) && (x + i < 500 && y + j < 500))
					{
						// Don't include itself
						if (!(i == 0 && j == 0))
						{
							// There may be an error with this line, you can ignore it
							nodeMap[y][x].neighbours.push_back(&nodeMap[y + j][x + i]);
						}
					}
				}
			}
		}
	}

	return nodeMap;
}

// Scales the perlinArray so that the highest value is 1 an dth elowest is 0
float** Scale(float** perlinArray)
{
	float max = 0.0f;
	float min = 1000.0f;

	// Finds the highest value
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			if (perlinArray[y][x] > max)
			{
				max = perlinArray[y][x];
			}
		}
	}

	// Finds the lowest value
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			if (perlinArray[y][x] < min)
			{
				min = perlinArray[y][x];
			}
		}
	}

	// Scales the array
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			perlinArray[y][x] = (perlinArray[y][x] - min) / (max - min);
		}
	}

	return perlinArray;
}

// Generates a number of rivers, with a minimum length 
float** GenerateRivers(float** map, int xSize, int ySize, int numberOfRivers, int minRiverLength, float heightFromTop, int betterGen)
{
	// Initialise the random number generator
	std::random_device rd;
	std::mt19937 gen(rd());

	int xPos = 0;
	int yPos = 0;
	
	// Create the output map
	float** riverMap;
	riverMap = InitGrid(500, 500);

	// Intialises node array
	Node** nodeArray;
	nodeArray = InitNeighbours(500, 500, map);

	std::cout << "Initialised node array" << std::endl;

	std::vector<Vector2> highPoints;

	// Find the highest point in the hight map
	float maxHeight = 0.0f;
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			if (map[y][x] > maxHeight)
			{
				maxHeight = map[y][x];
			}
		}
	}

	// If a point in the height map is higher than (maxHeight - heightFromTop) add it as a vector
	// This is all the possible river start positions
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			if (map[y][x] > maxHeight - heightFromTop)
			{
				Vector2 tempLocation;
				tempLocation.x = x;
				tempLocation.y = y;

				highPoints.push_back(tempLocation);
			}
		}
	}

	// If the user wants rivers
	if (numberOfRivers > 0)
	{
		bool finished = false;

		float neighbours[8];
		int riverLength = 0;
		int rNum = 0;
		std::vector<Vector2> currentPath;

		int count = 0;

		int xMoveOffset = 0;
		int yMoveOffset = 0;

		// While there is less rivers than alot amount AND ther is still posible spawn locations
		while(rNum < numberOfRivers && highPoints.size() > 0)
		{
			// Creates the random generator for numbers between 0 and one less than the number of posible spawn location
			std::uniform_int_distribution<> distribution(0, highPoints.size() - 1);
			int randomHighPoint = distribution(gen);

			// Randomly choose a starting location
			Vector2 startLocation = highPoints[randomHighPoint];
			highPoints.erase(highPoints.begin() + randomHighPoint);

			xPos = startLocation.x;
			yPos = startLocation.y;

			finished = false;

			currentPath.clear();
			
			// From the starting location, goes upwards until it can't
			while (!finished)
			{			
				Vector2 posistion;
				posistion.x = xPos;
				posistion.y = yPos;
				currentPath.push_back(posistion);

				// Finds the highest neighbour
				float max = map[yPos][xPos];
				int pos = -1;
				for (int i = 0; i < nodeArray[yPos][xPos].neighbours.size(); i++)
				{
					if (nodeArray[yPos][xPos].neighbours[i]->height > max)
					{
						max = nodeArray[yPos][xPos].neighbours[i]->height;
						pos = i;
					}

				}

				// Highest point found
				if (pos == -1)
				{
					finished = true;
					break;
				}

				// Move the current position to the chosen ceighbours position
				xMoveOffset = nodeArray[yPos][xPos].neighbours[pos]->x - xPos;
				yMoveOffset = nodeArray[yPos][xPos].neighbours[pos]->y - yPos;
				xPos += xMoveOffset;
				yPos += yMoveOffset;

			}

			// Reset the river back to the starting point
			finished = false;
			xPos = startLocation.x;
			yPos = startLocation.y;

			// From the starting point, travel down the path of least resistance
			while (!finished)
			{
				Vector2 posistion;
				posistion.x = xPos;
				posistion.y = yPos;
				currentPath.push_back(posistion);

				// Finds the lowest neighbour
				float min = map[yPos][xPos];
				int pos = -1;
				for (int i = 0; i < nodeArray[yPos][xPos].neighbours.size(); i++)
				{
					if (nodeArray[yPos][xPos].neighbours[i]->height <= min)
					{
						min = nodeArray[yPos][xPos].neighbours[i]->height;
						pos = i;
					}

				}

				// Lowest point found
				if (pos == -1)
				{
					finished = true;
					break;
				}


				// Move the current position to the chosen ceighbours position
				xMoveOffset = nodeArray[yPos][xPos].neighbours[pos]->x - xPos;
				yMoveOffset = nodeArray[yPos][xPos].neighbours[pos]->y - yPos;

				xPos += xMoveOffset;
				yPos += yMoveOffset;
			}

			// Checks if the current river is longer than the minimum river length
			if (currentPath.size() >= minRiverLength)
			{
				// Adds the river to the river map
				for (int i = 0; i < currentPath.size(); i++)
				{
					riverMap[currentPath[i].y][currentPath[i].x] = 1.0f;

					// Removes this river point from the possible starting locations 
					if (betterGen == 1)
					{
						for (int h = 0; h < highPoints.size(); h++)
						{
							if (currentPath[i].y == highPoints[h].y && currentPath[i].x == highPoints[h].x)
							{
								highPoints.erase(highPoints.begin() + h);
								break;
							}
						}
					}
				}
				rNum++;
			}
		}
		
		std::cout << rNum << " out of " << numberOfRivers << " river(s) generated" << endl;
		Sleep(1000);
	}

	return riverMap;
}

// Generates blurry circles, with a radius of iterations, at each point in map that has a value above minValue
float** BlurImage(float** map, int iterations, float minValue)
{
	float num = 0.0f;
	
	// Initilaises blur array
	float** blur;
	blur = InitGrid(500, 500);

	// Loops through the map
	for (int x = 0; x < 500; x++)
	{
		for (int y = 0; y < 500; y++)
		{
			if (map[y][x] >= minValue)
			{
				// Loops through Moore neighbourhood
				for (int i = -iterations; i <= iterations; i++)
				{
					for (int j = -iterations; j <= iterations; j++)
					{
						// If the neighbour is within the map
						if ((x + i >= 0 && y + j >= 0) && (x + i < 500 && y + j < 500))
						{
							num = islandify(x, y, x + i, y + j, iterations);
							if ((blur[y + j][x + i]) < (num - 0.0806051))
							{
								blur[y + j][x + i] = (num - 0.0806051);
							}
						}

					}
				}
			}
		}
	}

	return blur;
}

// 'Blurs' the map, iterations = how large the resultant blurred image is
float** BlurImagePlus(PerlinNoiseClass p, float** map, int iterations)
{
	float dist = 0.0f;
	float num = 0.0f;

	// Initialises the arrays
	float** blurArray;
	float** perlinArray;
	blurArray = InitGrid(500, 500);
	perlinArray = InitGrid(500, 500);

	// Creats a perlin map to reduce the river map by
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			perlinArray[y][x] = (FBM(p, x / 10.0f, y / 10.0f, 2.0f, 0.8f, 0.8, 2.0, 5, 0) + 1) / 2;
		}
	}

	// Initial blur
	blurArray = BlurImage(map, 6.0f, 1.0f);

	// Scales the perlin map between 0 and 1
	perlinArray = Scale(perlinArray);

	for (int x = 0; x < 500; x++)
	{
		for (int y = 0; y < 500; y++)
		{
			// If there is a river, reduce it by the relative perlin value
			if (blurArray[y][x] > 0.0f)
			{
				blurArray[y][x] -= perlinArray[y][x];

				// Make sure there are no -ve values
				if (blurArray[y][x] < 0)
				{
					blurArray[y][x] = 0.0f;
				}
			}
		}
	}

	// Scale river map to be between 0 and 1
	blurArray = Scale(blurArray);

	// Reblur the river map
	blurArray = BlurImage(blurArray, 10.0, 0.14f);
	
	return blurArray;
}

//Prompts the user to enter a int, loops until the input is a number, and its between min and max
int GetNum(int min, int max)
{
	int tempNum = 0;

	std::cin >> tempNum;
	while (cin.fail() || tempNum < min || tempNum > max) //if the users enters anything other than a number
	{
		std::cin.clear();
		std::cin.ignore(1000, '\n');

		std::cout << endl;

		std::cout << "Please input a valid integer >= to " << min << " and <= to " << max << ")" << endl << endl;
		std::cin >> tempNum;
	}

	return tempNum;
}

//Prompts the user to enter a float, loops until the input is a number, and its between min and max
float GetNum(float min, float max)
{
	float tempNum = 0;

	std::cin >> tempNum;
	while (cin.fail() || tempNum < min || tempNum > max) //if the users enters anything other than a number
	{
		std::cin.clear();
		std::cin.ignore(1000, '\n');

		std::cout << endl;

		std::cout << "Please input a valid float >= to " << min << " and <= to " << max << ")" << endl << endl;
		std::cin >> tempNum;
	}

	return tempNum;
}

// Generate the height map
void GeneratePerlinMap(float xSeed, float ySeed)
{
	// Initialize GDI+, used to save the generated image
	Gdiplus::GdiplusStartupInput gdiplusStartupInput;
	ULONG_PTR gdiplusToken;
	Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

	// .png definition
	CLSID pngClsid;
	GetEncoderClsid(L"image/png", &pngClsid);

	// The two images to be created
	Bitmap* perlinMap = new Bitmap(500.0f, 500.0f);
	Bitmap* riverMap = new Bitmap(500.0f, 500.0f);

	Color colour;

	// Creates and initialises the PerlinNoise class
	PerlinNoiseClass perlinNoise;
	perlinNoise.init();
	
	// Array of value, each float represents the colour value of a pixel (0 = black, 1 = white)
	float** perlinArray;
	perlinArray = InitGrid(500, 500);

	float** perlinArraySimple;
	perlinArraySimple = InitGrid(500, 500);

	// Initialises values
	float amplitude = 0.0f;
	float frequency = 0.0f;
	float persistance = 0.0f;
	float lacunarity = 0.0f;
	int octaves = 0.0f;
	float islandRange = 0.0f;
	int islands = 0;
	int antiIsland = 0;
	float redis = 0.0f;
	int ridged = 0;

	// Gets user input for the noise generation values
	std::cout << "Do you want to use the default values? (1 = yes, 0 = no): ";
	int answer = GetNum(0, 1);
	// Default values
	if (answer == 1)
	{
		amplitude = 2.0f;
		frequency = 0.5f;
		persistance = 0.5f;
		lacunarity = 2.0f;
		octaves = 5;
		redis = 0.7f;
		islandRange = 250.0f;
		ridged = 0;
	}
	else
	{
		std::cout << "Random values? (1 = yes, 0 = no): ";
		if (GetNum(0, 1) == 1)
		{
			// Radnomise the values
			amplitude = ((rand() % 50) / 10.0f) + 0.1f;
			frequency = ((rand() % 10) / 10.0f) + 0.2f;
			persistance = ((rand() % 20) / 10.0f) + 0.1f;
			lacunarity = ((rand() % 50) / 10.0f) + 0.1f;
			octaves = rand() % 10;
			redis = ((rand() % 30) / 10.0f) + 0.1f;
			ridged = rand() % 3;

			std::cout << "Amplitude: " << amplitude << std::endl;
			std::cout << "Frequency: " << frequency << std::endl;
			std::cout << "Persistance: " << persistance << std::endl;
			std::cout << "Lacunarity: " << lacunarity << std::endl;
			std::cout << "Octaves: " << octaves << std::endl;
			std::cout << "Redistribution: " << redis << std::endl;
			switch (ridged)
			{
			case 1:
				std::cout << "Using ridged noise" << std::endl;
				break;
			case 2:
				std::cout << "Using inverse ridged noise" << std::endl;
				break;
			default:
				break;
			}
		}
		else
		{
			// User inputted values
			std::cout << "Amplitude: ";
			amplitude = GetNum(0.0f, 10.0f);
			std::cout << "Frequency: ";
			frequency = GetNum(0.0f, 10.0f);
			std::cout << "Persistance: ";
			persistance = GetNum(0.0f, 10.0f);
			std::cout << "Lacunarity: ";
			lacunarity = GetNum(0.0f, 10.0f);
			std::cout << "Octaves: ";
			octaves = GetNum(0, 8);
			std::cout << "Redistribution: ";
			redis = GetNum(0.1f, 5.0f);
			std::cout << "Use Ridged Noise? (0 = no, 1 = yes, 2 = inverse ridged): ";
			ridged = GetNum(0, 2);
		}
	}

	bool safe = true;
	// Asks weither or not the user wants to generate the map as an island
	std::cout << endl << "Would you like to generate an island? (1 = yes, 0 = no): ";
	islands = GetNum(0, 1);
	if (islands == 1)
	{
		std::cout << "Would you like it to be an inverted island? (1 = yes, 0 = no): ";
		antiIsland = GetNum(0, 1);

		// If yes, them the island's radius can be inputed by the user
		std::cout << "Do you want the default island size? (1 = yes, 0 = no): ";
		if (GetNum(0, 1) == 0)
		{
			safe = false;
		}
		if (!safe)
		{
			std::cout << "Enter island radius: ";
			islandRange = GetNum(1.0f, 1000.0f);
		}
	}

	////// Generates the base and simple height map //////
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			float vec[2];
			vec[0] = ((float)x) / 100.0f;
			vec[1] = ((float)y) / 100.0f;

			perlinArray[y][x] = FBM(perlinNoise, (x / 50.0f) + xSeed, (y / 50.0f) + ySeed, amplitude, frequency, persistance, lacunarity, octaves, ridged);
			perlinArraySimple[y][x] = FBM(perlinNoise, (x / 50.0f) + xSeed, (y / 50.0f) + ySeed, amplitude, frequency, persistance, lacunarity, octaves/2, ridged);
		}
	}

	// Scales the height between 0 and 1
	perlinArray = Scale(perlinArray);
	perlinArraySimple = Scale(perlinArraySimple);

	// Redistribution
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			perlinArray[y][x] = pow(perlinArray[y][x], redis);
			perlinArraySimple[y][x] = pow(perlinArraySimple[y][x], redis);
		}
	}

	// Scales the height between 0 and 1
	perlinArray = Scale(perlinArray);
	perlinArraySimple = Scale(perlinArraySimple);

	float min = 1.0f;

	float pValue = 0.0f;
	float pValueSimple = 0.0f;
	float islandValue = 0.0f;
	float finalValue = 0.0f;
	float finalValueSimple = 0.0f;

	////// Generates the island //////
	if (islands == 1)
	{
		for (int x = 0; x < 500.0f; x++)
		{
			for (int y = 0; y < 500.0f; y++)
			{
				// Height map values
				pValue = perlinArray[y][x];
				pValueSimple = perlinArraySimple[y][x];

				islandValue = (islandify(250, 250, (float)x, (float)y, islandRange));

				// If the user want to generate an island
				if (islands == 1)
				{
					// User want inverted island
					if (antiIsland == 1)
					{
						islandValue = 1 - islandValue;
					}

					finalValue = pValue * (islandValue);
					finalValueSimple = pValueSimple * (islandValue);
				}

				perlinArray[y][x] = finalValue;
				perlinArraySimple[y][x] = finalValueSimple;

			}
		}
	}


	////// River generation //////
	int numOfRivers = 0;
	int minRiverLength = 0;
	int maxRiverLength = 0;
	float heightFromTop = 0.0f;
	int betterGen = 0;

	// Get user input
	std::cout << endl << "Do you want to generate rivers? (1 = yes, 0 = no): ";
	if (GetNum(0, 1) == 1)
	{
		std::cout << "Number of river: ";
		numOfRivers = GetNum(1, 500);
		std::cout << "Minumin length of river (length in pixels): ";
		minRiverLength = GetNum(1, 200);
		std::cout << "Lowest distance from the top a river can start: ";
		heightFromTop = GetNum(0.0f, 1.0f);
		std::cout << "Make sure that each river will not spawn inside another? (1 = yes, 0 = no): ";
		if (GetNum(0, 1) == 1)
		{
			std::cout << "WARNING: THIS TAKES A WHILE" << std::endl;
			Sleep(500);
			std::cout << "Are you sure? (1 = yes, 0 = no): ";
			betterGen = GetNum(0, 1);
		}
	}

	// Creates and initialises the river/river blur arrays
	float** riverArray;
	float** riverArrayBlur;
	riverArray = InitGrid(500, 500);
	riverArrayBlur = InitGrid(500, 500); 

	// Generates the river map, if the user doesnt want river it just return a blank map
	riverArray = GenerateRivers(perlinArraySimple, 500, 500, numOfRivers, minRiverLength, heightFromTop, betterGen);

	// Blurs the river map
	riverArrayBlur = BlurImagePlus(perlinNoise, riverArray, 10);

	////// Creates the .pngs //////
	for (int x = 0; x < 500.0f; x++)
	{
		for (int y = 0; y < 500.0f; y++)
		{
			// Convert river map from 0 -> 1 to 0 -> 255
			float rNum = riverArrayBlur[y][x] * 255.0f;
			
			// Sets the pixel in the river bitmap
			colour = Color(255.0f, rNum, rNum, rNum);			
			riverMap->SetPixel(x, y, colour);

			// If there is a river, reduce the height map
			float num = perlinArray[y][x];
			if (riverArrayBlur[y][x] != 0.0f)
			{
				num -= riverArrayBlur[y][x] / 10.0f;
				if (num < 0)
				{
					num = 0;
				}
			}

			// Convert height map from 0 -> 1 to 0 -> 255
			num *= 255.0f;

			// sets the pixel in the height bitmap
			colour = Color(255.0f, num, num, num);
			perlinMap->SetPixel(x, y, colour);
		}
	}
	
	// Clears the console
	system("cls");

	// Saves the bitmaps to .pngs
	Status stat;
	stat = perlinMap->Save(L"perlinMap.png", &pngClsid, NULL);
	stat = riverMap->Save(L"riverMap.png", &pngClsid, NULL);

	// Deletes the bitmaps
	delete perlinMap;
	delete riverMap;

	// Shuts down gdiplus
	Gdiplus::GdiplusShutdown(gdiplusToken);
}

int main()
{
	srand(time(NULL));
	
	bool running = true;

	while (running)
	{
		std::cout << "Do you want to generate a perlin height map? (1 = yes, 0 = no): ";
		if(GetNum(0, 1) == 1)
		{
			GeneratePerlinMap(rand() % 1000, rand() % 1000);
		}
		else
		{
			running = false;
			break;
		}
	}

	std::cout << "k thanks bye" << endl;

	return 0;
}

