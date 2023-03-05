describe("basic", () => {
  it("succeeds", () => {
    expect(1 + 1).toBe(2);
  });

  it("fails", () => {
    expect(1 + 1).not.toBe(2);
  });

  it.each([
    [1, 1, 2],
    [1, 2, 3],
    [4, 5, 9],
  ])('all successful: %d + %d = %d', (a, b, sum) => {
    expect(a + b).toBe(sum);
  });

  it.each([
    [1, 1, 3],
    [1, 2, 4],
    [4, 4, 9],
  ])('all unsuccessful: %d + %d = %d', (a, b, sum) => {
    expect(a + b).toBe(sum);
  });

  it.each([
    [1, 1, 2],
    [1, 2, 4],
  ])('overall unsuccessful: %d + %d = %d', (a, b, sum) => {
    expect(a + b).toBe(sum);
  });
});
