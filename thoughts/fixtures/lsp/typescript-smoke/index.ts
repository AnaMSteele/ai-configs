export function greet(name: string): string {
  return `Hello, ${name}`;
}

const message = greet(123);
console.log(message);
