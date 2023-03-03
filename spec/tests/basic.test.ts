describe("basic", () => {
  it("succeeds", () => {
    expect(1 + 1).toBe(2);
  });

  it("fails", () => {
    expect(1 + 1).not.toBe(2);
  });

  it.each([
    [1, 1, 2],
    [1, 2, 3]
  ])('mix', (a, b, sum) => {
    expect(a + b).toBe(sum);
  });
});
