// ============================================================
// PROGRAM      : Shape Generator with Color
// FILE         : ShapeGenerator.cs
// LANGUAGE     : C# (.NET)
//
// SHAPES  : Circle, Square, Rectangle, Triangle, Diamond
// COLORS  : Red, Green, Blue
// MODES   : Filled or Hollow
// EXTRAS  : Custom draw character, Repeat option
// ============================================================

using System;

class ShapeGenerator
{
    // --------------------------------------------------------
    // ENTRY POINT
    // --------------------------------------------------------
    static void Main()
    {
        bool running = true;
        while (running)
        {
            Console.WriteLine("\n============================================");
            Console.WriteLine("        SHAPE GENERATOR  (C#)              ");
            Console.WriteLine("============================================");
            Console.WriteLine("  1. Circle");
            Console.WriteLine("  2. Square");
            Console.WriteLine("  3. Rectangle");
            Console.WriteLine("  4. Triangle");
            Console.WriteLine("  5. Diamond");
            Console.WriteLine("  6. Quit");
            Console.WriteLine("============================================");
            Console.Write("  Your choice: ");

            string choice = ReadLine();

            if      (choice == "1") DrawShape("circle");
            else if (choice == "2") DrawShape("square");
            else if (choice == "3") DrawShape("rectangle");
            else if (choice == "4") DrawShape("triangle");
            else if (choice == "5") DrawShape("diamond");
            else if (choice == "6" || choice == "q")
            {
                Console.WriteLine("\n  Goodbye! Thank you.\n");
                running = false;
            }
            else
            {
                Console.WriteLine("\n  [!] Invalid input. Please try again.");
            }
        }
    }

    // --------------------------------------------------------
    // Safe ReadLine: trims whitespace and carriage returns.
    // Fixes input issues on online compilers and Windows terminals.
    // --------------------------------------------------------
    static string ReadLine()
    {
        string input = Console.ReadLine();
        if (input == null) return "";
        return input.Trim().Replace("\r", "").Replace("\n", "");
    }

    // --------------------------------------------------------
    // DrawShape: collects options then draws the chosen shape
    // --------------------------------------------------------
    static void DrawShape(string shape)
    {
        ConsoleColor color = AskColor();
        bool hollow        = AskMode();
        char drawChar      = AskChar();

        int width  = 0;
        int height = 0;

        if (shape == "rectangle")
        {
            width  = AskSize("  Width  (3-9): ");
            height = AskSize("  Height (3-9): ");
        }
        else
        {
            width = AskSize("  Size   (3-9): ");
        }

        bool again = true;
        while (again)
        {
            Console.ForegroundColor = color;

            if      (shape == "circle")    DrawCircle(width, hollow, drawChar);
            else if (shape == "square")    DrawSquare(width, hollow, drawChar);
            else if (shape == "rectangle") DrawRectangle(width, height, hollow, drawChar);
            else if (shape == "triangle")  DrawTriangle(width, hollow, drawChar);
            else if (shape == "diamond")   DrawDiamond(width, hollow, drawChar);

            Console.ResetColor();
            again = AskRepeat();
        }
    }

    // --------------------------------------------------------
    // SHAPE 1: CIRCLE
    // Filled : draw char where x*x + y*y <= r*r
    // Hollow : draw char where (r-1)^2 <= x*x+y*y <= r*r
    // --------------------------------------------------------
    static void DrawCircle(int r, bool hollow, char c)
    {
        for (int y = -r; y <= r; y++)
        {
            for (int x = -r; x <= r; x++)
            {
                int dist = x * x + y * y;
                bool onShape;

                if (hollow)
                    onShape = dist >= (r - 1) * (r - 1) && dist <= r * r;
                else
                    onShape = dist <= r * r;

                Console.Write(onShape ? c : ' ');
            }
            Console.WriteLine();
        }
    }

    // --------------------------------------------------------
    // SHAPE 2: SQUARE
    // Hollow : border cells only (first/last row or col)
    // --------------------------------------------------------
    static void DrawSquare(int size, bool hollow, char c)
    {
        for (int row = 1; row <= size; row++)
        {
            for (int col = 1; col <= size; col++)
            {
                bool border = row == 1 || row == size ||
                              col == 1 || col == size;
                bool onShape = hollow ? border : true;
                Console.Write(onShape ? c : ' ');
            }
            Console.WriteLine();
        }
    }

    // --------------------------------------------------------
    // SHAPE 3: RECTANGLE
    // Same as square but width != height
    // --------------------------------------------------------
    static void DrawRectangle(int w, int h, bool hollow, char c)
    {
        for (int row = 1; row <= h; row++)
        {
            for (int col = 1; col <= w; col++)
            {
                bool border = row == 1 || row == h ||
                              col == 1 || col == w;
                bool onShape = hollow ? border : true;
                Console.Write(onShape ? c : ' ');
            }
            Console.WriteLine();
        }
    }

    // --------------------------------------------------------
    // SHAPE 4: ISOSCELES TRIANGLE (tip at top)
    // Row r: print (size-r) spaces, then (2r-1) chars
    // Hollow : edges and base only
    // --------------------------------------------------------
    static void DrawTriangle(int size, bool hollow, char c)
    {
        for (int row = 1; row <= size; row++)
        {
            // leading spaces
            for (int s = 0; s < size - row; s++)
                Console.Write(' ');

            int count = 2 * row - 1;
            for (int col = 0; col < count; col++)
            {
                bool edge = row == 1 || row == size ||
                            col == 0 || col == count - 1;
                bool onShape = hollow ? edge : true;
                Console.Write(onShape ? c : ' ');
            }
            Console.WriteLine();
        }
    }

    // --------------------------------------------------------
    // SHAPE 5: DIAMOND
    // Top half    row 1..size  : spaces=(size-row), chars=(2*row-1)
    // Bottom half row size-1..1: mirror of top
    // Hollow : edges only; widest row is fully filled
    // --------------------------------------------------------
    static void DrawDiamond(int size, bool hollow, char c)
    {
        for (int row = 1; row <= size; row++)
            PrintDiamondRow(row, size, hollow, c);

        for (int row = size - 1; row >= 1; row--)
            PrintDiamondRow(row, size, hollow, c);
    }

    static void PrintDiamondRow(int row, int size, bool hollow, char c)
    {
        for (int s = 0; s < size - row; s++)
            Console.Write(' ');

        int count = 2 * row - 1;
        for (int col = 0; col < count; col++)
        {
            bool edge = row == size || col == 0 || col == count - 1;
            bool onShape = hollow ? edge : true;
            Console.Write(onShape ? c : ' ');
        }
        Console.WriteLine();
    }

    // --------------------------------------------------------
    // INPUT HELPERS - all use safe ReadLine() with validation
    // --------------------------------------------------------

    static ConsoleColor AskColor()
    {
        while (true)
        {
            Console.Write("\n  Color  : 1=Red  2=Green  3=Blue : ");
            string input = ReadLine();

            if (input == "1") return ConsoleColor.Red;
            if (input == "2") return ConsoleColor.Green;
            if (input == "3") return ConsoleColor.Blue;

            Console.WriteLine("  [!] Invalid. Enter 1, 2, or 3.");
        }
    }

    static bool AskMode()
    {
        while (true)
        {
            Console.Write("\n  Mode   : 1=Filled  2=Hollow    : ");
            string input = ReadLine();

            if (input == "1") return false;
            if (input == "2") return true;

            Console.WriteLine("  [!] Invalid. Enter 1 or 2.");
        }
    }

    static char AskChar()
    {
        Console.Write("\n  Draw char (press Enter for *)  : ");
        string input = ReadLine();
        return (input.Length == 0) ? '*' : input[0];
    }

    static int AskSize(string prompt)
    {
        while (true)
        {
            Console.Write("\n" + prompt);
            string input = ReadLine();

            // parse and validate range 3-9
            if (int.TryParse(input, out int val) && val >= 3 && val <= 9)
                return val;

            Console.WriteLine("  [!] Invalid. Enter a number 3 to 9.");
        }
    }

    static bool AskRepeat()
    {
        while (true)
        {
            Console.Write("\n  Draw again? (y/n) : ");
            string input = ReadLine().ToLower();

            if (input == "y") return true;
            if (input == "n") return false;

            Console.WriteLine("  [!] Invalid. Enter y or n.");
        }
    }
}
