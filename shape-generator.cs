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
                // Tanmay Sarkar Emon //
                    //TP092959//  

using System; // needed to use Console, Math and other basic stuff

class ShapeGenerator // main class that holds all the shape logic
{
    // --------------------------------------------------------
    // ENTRY POINT
    // --------------------------------------------------------
    static void Main() // program execution starts from here
    {
        bool running = true; // this flag controls the main loop, set false to exit

        while (running) // keep showing the menu until user quits
        {
            // printing the menu options line by line
            Console.WriteLine("\n============================================"); // top border
            Console.WriteLine("        SHAPE GENERATOR  (C#)              "); // title
            Console.WriteLine("============================================"); // border below title
            Console.WriteLine("  1. Circle");     // option 1
            Console.WriteLine("  2. Square");     // option 2
            Console.WriteLine("  3. Rectangle");  // option 3
            Console.WriteLine("  4. Triangle");   // option 4
            Console.WriteLine("  5. Diamond");    // option 5
            Console.WriteLine("  6. Quit");       // option 6 exits the program
            Console.WriteLine("============================================"); // bottom border
            Console.Write("  Your choice: "); // Write (not WriteLine) so cursor stays on same line

            string choice = ReadLine(); // read what the user typed

            // check which option was chosen and call DrawShape with the shape name
            if      (choice == "1") DrawShape("circle");
            else if (choice == "2") DrawShape("square");
            else if (choice == "3") DrawShape("rectangle");
            else if (choice == "4") DrawShape("triangle");
            else if (choice == "5") DrawShape("diamond");
            else if (choice == "6" || choice == "q") // accept both 6 and q for quit
            {
                Console.WriteLine("\n  Goodbye! Thank you.\n"); // farewell message
                running = false; // set flag to false so the while loop ends
            }
            else
            {
                Console.WriteLine("\n  [!] Invalid input. Please try again."); // wrong input message
            }
        }
    }

    // --------------------------------------------------------
    // Safe ReadLine: trims whitespace and carriage returns.
    // Fixes input issues on online compilers and Windows terminals.
    // --------------------------------------------------------
    static string ReadLine() // wrapper around Console.ReadLine() to clean the input
    {
        string input = Console.ReadLine(); // read a line from keyboard
        if (input == null) return ""; // if nothing was typed return empty string to avoid crash
        return input.Trim().Replace("\r", "").Replace("\n", ""); // remove spaces and newline chars from both ends
    }

    // --------------------------------------------------------
    // DrawShape: collects options then draws the chosen shape
    // --------------------------------------------------------
    static void DrawShape(string shape) // takes the shape name and handles all input before drawing
    {
        ConsoleColor color = AskColor(); // ask user to pick a color and store it
        bool hollow        = AskMode();  // ask filled or hollow, returns true if hollow
        char drawChar      = AskChar();  // ask which character to draw with, default is *

        int width  = 0; // will hold width value
        int height = 0; // will hold height value, only used for rectangle

        if (shape == "rectangle") // rectangle needs separate width and height
        {
            width  = AskSize("  Width  (3-9): "); // get width from user
            height = AskSize("  Height (3-9): "); // get height from user
        }
        else // all other shapes just need one size value
        {
            width = AskSize("  Size   (3-9): "); // single size works as radius or side length
        }

        bool again = true; // controls the repeat loop
        while (again) // keep drawing until user says no
        {
            Console.ForegroundColor = color; // set terminal text color before drawing

            // call the correct draw method based on shape name
            if      (shape == "circle")    DrawCircle(width, hollow, drawChar);
            else if (shape == "square")    DrawSquare(width, hollow, drawChar);
            else if (shape == "rectangle") DrawRectangle(width, height, hollow, drawChar);
            else if (shape == "triangle")  DrawTriangle(width, hollow, drawChar);
            else if (shape == "diamond")   DrawDiamond(width, hollow, drawChar);

            Console.ResetColor(); // reset color back to default after shape is drawn
            again = AskRepeat();  // ask if user wants to draw the same shape again
        }
    }

    // --------------------------------------------------------
    // SHAPE 1: CIRCLE
    // Filled : draw char where x*x + y*y <= r*r
    // Hollow : draw char where (r-1)^2 <= x*x+y*y <= r*r
    // --------------------------------------------------------
    static void DrawCircle(int r, bool hollow, char c) // r = radius, c = draw character
    {
        for (int y = -r; y <= r; y++) // loop through each row from top (-r) to bottom (+r)
        {
            for (int x = -r; x <= r; x++) // loop through each column from left to right
            {
                int dist = x * x + y * y; // distance squared from center using Pythagoras (no sqrt needed)
                bool onShape; // will decide if we print char or space here

                if (hollow)
                    onShape = dist >= (r - 1) * (r - 1) && dist <= r * r; // only the ring border, not inside
                else
                    onShape = dist <= r * r; // any point inside or on the circle edge

                Console.Write(onShape ? c : ' '); // print char if on shape, else print space
            }
            Console.WriteLine(); // move to next line after finishing each row
        }
    }

    // --------------------------------------------------------
    // SHAPE 2: SQUARE
    // Hollow : border cells only (first/last row or col)
    // --------------------------------------------------------
    static void DrawSquare(int size, bool hollow, char c) // size = number of rows and columns
    {
        for (int row = 1; row <= size; row++) // loop rows 1 to size
        {
            for (int col = 1; col <= size; col++) // loop columns 1 to size
            {
                bool border = row == 1 || row == size ||
                              col == 1 || col == size; // true if this cell is on any edge

                bool onShape = hollow ? border : true; // hollow shows border only, filled shows everything
                Console.Write(onShape ? c : ' ');      // print character or space
            }
            Console.WriteLine(); // newline after each row
        }
    }

    // --------------------------------------------------------
    // SHAPE 3: RECTANGLE
    // Same as square but width != height
    // --------------------------------------------------------
    static void DrawRectangle(int w, int h, bool hollow, char c) // w = width, h = height
    {
        for (int row = 1; row <= h; row++) // loop through rows using height
        {
            for (int col = 1; col <= w; col++) // loop through columns using width
            {
                bool border = row == 1 || row == h ||
                              col == 1 || col == w; // edge detection same as square but uses h and w

                bool onShape = hollow ? border : true; // only border if hollow
                Console.Write(onShape ? c : ' ');      // print char or space
            }
            Console.WriteLine(); // end of row
        }
    }

    // --------------------------------------------------------
    // SHAPE 4: ISOSCELES TRIANGLE (tip at top)
    // Row r: print (size-r) spaces, then (2r-1) chars
    // Hollow : edges and base only
    // --------------------------------------------------------
    static void DrawTriangle(int size, bool hollow, char c) // size = number of rows
    {
        for (int row = 1; row <= size; row++) // each row of the triangle
        {
            // print leading spaces to center the triangle
            for (int s = 0; s < size - row; s++) // number of spaces = size minus current row
                Console.Write(' '); // one space at a time

            int count = 2 * row - 1; // how many characters on this row (row1=1, row2=3, row3=5...)
            for (int col = 0; col < count; col++) // loop through each character position
            {
                bool edge = row == 1 || row == size ||
                            col == 0 || col == count - 1; // tip, base, left slope, right slope

                bool onShape = hollow ? edge : true; // show edge only if hollow
                Console.Write(onShape ? c : ' ');    // print char or space
            }
            Console.WriteLine(); // move to next row
        }
    }

    // --------------------------------------------------------
    // SHAPE 5: DIAMOND
    // Top half    row 1..size  : spaces=(size-row), chars=(2*row-1)
    // Bottom half row size-1..1: mirror of top
    // Hollow : edges only; widest row is fully filled
    // --------------------------------------------------------
    static void DrawDiamond(int size, bool hollow, char c) // draws diamond by splitting into top and bottom halves
    {
        for (int row = 1; row <= size; row++)      // top half goes from row 1 up to the widest row
            PrintDiamondRow(row, size, hollow, c); // print each row of the top half

        for (int row = size - 1; row >= 1; row--)  // bottom half mirrors top half in reverse
            PrintDiamondRow(row, size, hollow, c); // print each row of the bottom half
    }

    static void PrintDiamondRow(int row, int size, bool hollow, char c) // helper to print one row of the diamond
    {
        for (int s = 0; s < size - row; s++) // print leading spaces before the characters
            Console.Write(' ');

        int count = 2 * row - 1; // number of characters on this row, same formula as triangle
        for (int col = 0; col < count; col++) // go through each character position
        {
            bool edge = row == size || col == 0 || col == count - 1; // widest row, left edge, or right edge
            bool onShape = hollow ? edge : true; // hollow shows only edges, filled shows all
            Console.Write(onShape ? c : ' ');    // print char or space based on condition
        }
        Console.WriteLine(); // done with this row, go to next line
    }

    // --------------------------------------------------------
    // INPUT HELPERS - all use safe ReadLine() with validation
    // --------------------------------------------------------

    static ConsoleColor AskColor() // keeps asking until user enters 1, 2, or 3
    {
        while (true) // infinite loop, will return when valid input received
        {
            Console.Write("\n  Color  : 1=Red  2=Green  3=Blue : "); // show color options
            string input = ReadLine(); // read the choice

            if (input == "1") return ConsoleColor.Red;   // return red color enum
            if (input == "2") return ConsoleColor.Green; // return green color enum
            if (input == "3") return ConsoleColor.Blue;  // return blue color enum

            Console.WriteLine("  [!] Invalid. Enter 1, 2, or 3."); // wrong input, loop again
        }
    }

    static bool AskMode() // asks filled or hollow, returns bool
    {
        while (true)
        {
            Console.Write("\n  Mode   : 1=Filled  2=Hollow    : "); // show mode options
            string input = ReadLine(); // read the answer

            if (input == "1") return false; // filled mode, return false
            if (input == "2") return true;  // hollow mode, return true

            Console.WriteLine("  [!] Invalid. Enter 1 or 2."); // re-prompt on wrong input
        }
    }

    static char AskChar() // asks for draw character, uses * if user just presses Enter
    {
        Console.Write("\n  Draw char (press Enter for *)  : "); // prompt for character
        string input = ReadLine();                              // read the input
        return (input.Length == 0) ? '*' : input[0];           // if empty use *, otherwise take first character typed
    }

    static int AskSize(string prompt) // reusable method to ask for a number between 3 and 9
    {
        while (true)
        {
            Console.Write("\n" + prompt); // show the given prompt text (width or height or size)
            string input = ReadLine();    // read user input

            // int.TryParse converts string to int safely without throwing an exception
            if (int.TryParse(input, out int val) && val >= 3 && val <= 9) // check it parsed AND is in range
                return val; // valid number, send it back

            Console.WriteLine("  [!] Invalid. Enter a number 3 to 9."); // out of range or not a number
        }
    }

    static bool AskRepeat() // asks if user wants to draw the same shape again
    {
        while (true)
        {
            Console.Write("\n  Draw again? (y/n) : "); // prompt
            string input = ReadLine().ToLower();        // convert to lowercase so Y and y both work

            if (input == "y") return true;  // yes, draw again
            if (input == "n") return false; // no, go back to main menu

            Console.WriteLine("  [!] Invalid. Enter y or n."); // wrong input, ask again
        }
    }
}
