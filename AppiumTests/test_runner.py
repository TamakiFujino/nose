import unittest
import sys
import os

if __name__ == "__main__":
    # Get all test files in the tests directory
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover('tests')
    
    # Run the tests
    test_runner = unittest.TextTestRunner()
    result = test_runner.run(test_suite)
    
    # Exit with appropriate status code
    sys.exit(not result.wasSuccessful())