#!/usr/bin/env python3

class Calculator:
    def __init__(self):
        self.result = 0
    
    def add(self, x):
        self.result += x
        return self.result
    
    def subtract(self, x):
        self.result -= x
        return self.result
    
    def multiply(self, x):
        self.result *= x
        return self.result
    
    def clear(self):
        self.result = 0
        return self.result
    
    def get_result(self):
        return self.result

# Example usage
if __name__ == "__main__":
    calc = Calculator()
    print(f"Initial: {calc.get_result()}")
    print(f"Add 5: {calc.add(5)}")
    print(f"Multiply by 3: {calc.multiply(3)}")
    print(f"Subtract 2: {calc.subtract(2)}")
    print(f"Result: {calc.get_result()}")
    print(f"Clear: {calc.clear()}")