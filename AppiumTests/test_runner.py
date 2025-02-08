import unittest

if __name__ == "__main__":
    test_loader = unittest.TestLoader()
    test_suite = test_loader.discover('test_cases')
    test_runner = unittest.TextTestRunner()
    test_runner.run(test_suite)
