"""
Bootstrap Loader entry point.
"""

from .loader import initialize

def main():
    result = initialize()
    print(result.state)

if __name__ == "__main__":
    main()
