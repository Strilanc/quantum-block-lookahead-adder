from typing import Callable, Union, List, Optional

import dataclasses
import math
import pathlib

import cirq


@dataclasses.dataclass
class SimpleFormula:
    O_1: bool = False
    b: int = 0
    n_over_b: int = 0
    lg_n_over_b: int = 0
    constant: float = 0
    lg_n: Union[int, float] = 0
    sqrt_n: Union[int, float] = 0
    n: Union[int, float] = 0
    n2: Union[int, float] = 0

    def value(self, n: int, b: int):
        return (
            self.n2 * n * n
            + self.n * n
            + self.sqrt_n * int(math.ceil(math.sqrt(n)))
            + self.lg_n * int(math.ceil(math.log2(n)))
            + self.constant
            + (10 if self.O_1 else 0)
            + self.b * b
            + self.n_over_b * int(math.ceil(n / b))
            + self.lg_n_over_b * int(math.ceil(math.log2(max(n / b, 1))))
        )

    def latex(self) -> str:

        def factor(x: Union[int, float]) -> str:
            if x == 1:
                return ''
            if x == -1:
                return '-'
            return str(x)

        terms = []
        if self.n2:
            terms.append(factor(self.n2) + "n^2")
        if self.n:
            terms.append(factor(self.n) + "n")
        if self.b:
            terms.append(factor(self.b) + r"b")
        if self.n_over_b:
            terms.append(factor(self.n_over_b) + r"\frac{n}{b}")
        if self.lg_n_over_b:
            terms.append(factor(self.lg_n_over_b) + r"\lg \frac{n}{b}")
        if self.sqrt_n:
            terms.append(factor(self.sqrt_n) + r"\sqrt{n}")
        if self.lg_n:
            terms.append(factor(self.lg_n) + r"\lg n")
        if self.O_1:
            terms.append("O(1)")
        if self.constant:
            terms.append(str(self.constant))
        if not terms:
            return "0"
        result = "$" + " + ".join(terms) + "$"
        result = result.replace('+ -', '- ')
        return result


class Tot:
    def __init__(self, heights: Callable[[int], List[float]]):
        self.heights = heights

    @staticmethod
    def sequence(*items: 'Tot') -> 'Tot':
        result = items[0]
        for item in items[1:]:
            result = result.then(item)
        return result

    def __mul__(self, other: int) -> 'Tot':
        return Tot(lambda n: [e * other for e in self.heights(n)])

    def reversed(self):
        return Tot(lambda n: self.heights(n)[::-1])

    def then(self, second: 'Tot', shift: int = 0) -> 'Tot':
        def f(n: int) -> List[float]:
            a = self.heights(n)
            b = second.heights(n)
            result = list(a)
            for k in range(len(b)):
                i = len(a) + k + shift
                while len(result) <= i:
                    result.append(0)
                result[i] += b[k]
            return result
        return Tot(f)

    def tikz_plot(self, n: int) -> str:
        return tikz_plot(self.heights(n))

    def overlap(self, second: 'Tot', shift: int = 0):
        def f(n: int) -> List[int]:
            a = self.heights(n)
            b = second.heights(n)
            result = list(a)
            for k in range(len(b)):
                i = k + shift
                while len(result) <= i:
                    result.append(0)
                result[i] += b[k]
            return result
        return Tot(f)


def fold_down(*, scale: float = 1, skip_start: int = 0, skip_end: int = 0, blocks: bool = False, sqrt: bool = False) -> Tot:
    def f(n: int) -> List[float]:
        result = []
        k = n
        if blocks:
            k = int(math.ceil(n / DEFAULT_B))
        if sqrt:
            k = int(math.ceil(math.sqrt(n)))
        for _ in range(skip_start):
            k >>= 1
        while k > 2**skip_end:
            result.append(k * scale)
            k >>= 1
        return result
    return Tot(f)


def hold(*, duration: Union[int, float, SimpleFormula], height: Union[int, float, SimpleFormula] = 1) -> Tot:
    if isinstance(duration, (int, float)):
        duration = SimpleFormula(constant=duration)
    if isinstance(height, (int, float)):
        height = SimpleFormula(constant=height)
    return Tot(lambda n: [height.value(n, DEFAULT_B)] * int(math.ceil(duration.value(n, DEFAULT_B))))


DEFAULT_N = 128
DEFAULT_B = 10


@dataclasses.dataclass
class Adder:
    author: str
    year: int
    citation: Optional[str]
    type: str
    in_place: bool
    toffolis: SimpleFormula
    reaction_depth: SimpleFormula
    workspace: SimpleFormula
    toffoli_usage: Optional[Tot] = None
    utilization: float = 1.0

    def toffoli_usage_tikz_plot(self) -> str:
        if self.toffoli_usage is None:
            t = self.reaction_depth.value(DEFAULT_N, DEFAULT_B)
            v = self.toffolis.value(DEFAULT_N, DEFAULT_B)
            r = hold(duration=t, height=v / t)
        else:
            r = self.toffoli_usage
        return r.tikz_plot(DEFAULT_N)

    def vol(self,
            *,
            n: int,
            factory_count: int,
            factory_period: int = 165,
            factory_area: int = 12 * 6,
            reaction_time: int = 10):
        return min(self.vol_b(
            n=n,
            b=b,
            factory_count=factory_count,
            factory_period=factory_period,
            factory_area=factory_area,
            reaction_time=reaction_time)
            for b in range(2, n + 1)
        )

    def vol_b(self,
            *,
            n: int,
            b: int,
            factory_count: int,
            factory_period: int = 165,
            factory_area: int = 12 * 6,
            reaction_time: int = 10):
        tof = self.toffolis.value(n, b)
        dep = self.reaction_depth.value(n, b)
        space = self.workspace.value(n, b)
        if self.in_place:
            space += 2*n
        else:
            space += 3*n
        time = max(factory_period * (tof / factory_count) / self.utilization, reaction_time * dep)
        result = factory_area * factory_period * tof + space * time
        result /= 1000 * 1000
        result = str(int(result))

        # 2 sig figs
        if len(result) > 2:
            result = result[:2] + '0' * (len(result) - 2)

        return result


def tikz_plot(heights: List[float]):
    def fy(v):
        if v == 0:
            return 0
        return 1 + int(math.ceil(math.log2(v)))

    start = r"\begin{tikzpicture}\fill[red] "
    points = [(0, -0.00001)]
    prev_y = 0
    for x, y in enumerate(heights):
        if y != prev_y:
            points.append((x, fy(prev_y)))
            points.append((x, fy(y)))
            prev_y = y
    points.append((len(heights), fy(prev_y)))
    points.append((len(heights), -0.00001))
    x_scale = 256  # max(e[0] for e in points)
    max_x = max(e[0] for e in points) / x_scale
    y_scale = 16  # max(e[1] for e in points)
    center = " -- ".join(f"({x / x_scale * 5},{y / y_scale})" for x, y in points)
    end = fr" -- cycle;\draw (0,0.5) -- (0,0) -- ({max_x * 5},0) -- ({max_x * 5},0.5); \end{{tikzpicture}}"
    return start + center + end


def make_table(adders: List[Adder]) -> str:
    adders = sorted(adders, key=lambda adder: (adder.reaction_depth.value(1000000, b=20) + adder.year*20, adder.year, adder.author))
    in_place_adders = [adder for adder in adders if adder.in_place]
    out_of_place_adders = [adder for adder in adders if not adder.in_place]
    in_place_row = 2
    out_of_place_row = 4 + len(in_place_adders)
    diagram = cirq.TextDiagramDrawer()
    diagram.write(0, in_place_row - 1, r"\hline")
    diagram.write(0, out_of_place_row - 1, r"\hline")
    params = [(100, 10), (1000, 100), (10000, 1000)]
    params = []
    vol_col = 7
    last_col = vol_col + len(params)

    diagram.write(0, 0, "Paper")
    diagram.write(1, 0, "&Place")
    diagram.write(2, 0, "&Type")
    diagram.write(3, 0, "&Toffolis")
    diagram.write(4, 0, "&Reaction Depth")
    diagram.write(5, 0, "&Workspace")
    diagram.write(6, 0, f"&Log Toffoli / Time (n={DEFAULT_N},b={DEFAULT_B})")
    diagram.write(last_col, 0, '\\\\')
    for c, (n, f) in enumerate(params):
        diagram.write(vol_col + c, 0, f"&V(n={n},f={f})")
    for (row, adders) in [(in_place_row, in_place_adders), (out_of_place_row, out_of_place_adders)]:
        for r, adder in enumerate(adders):
            diagram.write(0, row + r, f"{adder.author} ({adder.year})" + (r' \cite{' + adder.citation + '}' if adder.citation is not None else ''))
            diagram.write(1, row + r, '&' + ('in' if adder.in_place else 'out'))
            diagram.write(2, row + r, '&' + adder.type)
            diagram.write(3, row + r, '&' + adder.toffolis.latex())
            diagram.write(4, row + r, '&' + adder.reaction_depth.latex())
            diagram.write(5, row + r, '&' + adder.workspace.latex())
            diagram.write(6, row + r, '&' + adder.toffoli_usage_tikz_plot())
            for c, (n, f) in enumerate(params):
                diagram.write(vol_col + c, row + r, '&' + adder.vol(n=n, factory_count=f))
            diagram.write(last_col, row + r, '\\\\')
    contents = diagram.render(horizontal_spacing=1, vertical_spacing=0)
    return r"\begin{tabular}{r|c|c|l|l|l|l" + '|c' * len(params) + "}\n" + contents + "\n\end{tabular}"


def main():
    draper_lookahead_usage = Tot.sequence(
        # Prepare initial carries.
        hold(duration=1, height=SimpleFormula(n=1)),
        # P round.
        fold_down(skip_start=1).overlap(
            # G round.
            fold_down(skip_start=1),
            shift=1,
        ),
        # C round.
        fold_down(skip_start=1).reversed().overlap(
            # P^-1 round.
            fold_down(skip_start=1).reversed(),
            shift=1,
        ),
    )
    our_lookahead_usage = Tot.sequence(
        # Initial carries.
        hold(height=SimpleFormula(n=1), duration=1),
        # Grow centered ranges.
        fold_down(scale=2, skip_start=1),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=0, skip_start=1).reversed(),
            shift=1,
        ),
    )
    our_lookahead_usage_uncompute = Tot.sequence(
        # Initial carries.
        hold(height=SimpleFormula(n=1), duration=1),
        # Grow centered ranges.
        fold_down(scale=0, skip_start=1),
        # Spread zero-rooted ranges. (0 cost when uncomputing)
        fold_down(scale=0, skip_start=1).reversed(),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=2, skip_start=1).reversed(),
            shift=1,
        ),
    ).reversed()
    our_lookahead_usage_block_spread = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=2, skip_start=1, blocks=True),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1, blocks=True).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=0, skip_start=1, blocks=True).reversed(),
            shift=1
        ),
    )
    our_lookahead_usage_block_spread_uncompute = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=0, skip_start=1, blocks=True),
        # Spread zero-rooted ranges. (0 cost when uncomputing)
        fold_down(scale=0, skip_start=1, blocks=True).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=2, skip_start=1, blocks=True).reversed(),
            shift=1
        ),
    )
    our_block_usage = Tot.sequence(
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(b=1),
            height=SimpleFormula(n_over_b=2, constant=-1)),
        # Carry lookahead within blocks
        our_lookahead_usage_block_spread,
        # Choose result.
        hold(
            duration=SimpleFormula(b=1),
            height=SimpleFormula(n_over_b=1, constant=-1)),
        # Undo carry lookahead.
        our_lookahead_usage_block_spread_uncompute,
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(b=1),
            height=0),
    )
    our_block_usage_uncompute = Tot.sequence(
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(b=1),
            height=SimpleFormula(n_over_b=2, constant=-1)),
        # Carry lookahead within blocks
        our_lookahead_usage_block_spread,
        # Choose result.
        hold(
            duration=SimpleFormula(b=1),
            height=0),
        # Undo carry lookahead.
        our_lookahead_usage_block_spread_uncompute,
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(b=1),
            height=0),
    )

    our_lookahead_usage_sqrt_spread = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=2, skip_start=1, sqrt=True),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1, sqrt=True).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=0, skip_start=1, sqrt=True).reversed(),
            shift=1
        ),
    )
    our_lookahead_usage_sqrt_spread_uncompute = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=0, skip_start=1, sqrt=True),
        # Spread zero-rooted ranges. (0 cost when uncomputing)
        fold_down(scale=0, skip_start=1, sqrt=True).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=2, skip_start=1, sqrt=True).reversed(),
            shift=1
        ),
    )
    our_sqrt_usage = Tot.sequence(
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=SimpleFormula(sqrt_n=2, constant=-1)),
        # Carry lookahead within blocks
        our_lookahead_usage_sqrt_spread,
        # Choose result.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=SimpleFormula(sqrt_n=1, constant=-1)),
        # Undo carry lookahead.
        our_lookahead_usage_sqrt_spread_uncompute,
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=0),
    )
    our_sqrt_usage_uncompute = Tot.sequence(
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=SimpleFormula(sqrt_n=2, constant=-1)),
        # Carry lookahead within blocks
        our_lookahead_usage_block_spread,
        # Choose result.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=0),
        # Undo carry lookahead.
        our_lookahead_usage_block_spread_uncompute,
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(sqrt_n=1),
            height=0),
    )

    two_block_usage = Tot.sequence(
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(n=0.5),
            height=3),
        # Choose result.
        fold_down(skip_start=2).reversed(),
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(n=0.5),
            height=0),
    )
    two_block_usage_uncompute = Tot.sequence(
        # Undo initial ripple carry adders.
        hold(
            duration=SimpleFormula(n=0.5),
            height=2),
        # Choose result.
        fold_down(skip_start=2, scale=0).reversed(),
        # initial ripple carry adders.
        hold(
            duration=SimpleFormula(n=0.5),
            height=0),
    )

    comparison_table_tex = make_table([
        Adder(
            author="Cuccaro",
            year=2004,
            citation="cuccaro2004adder",
            type="Ripple Carry",
            in_place=True,
            toffolis=SimpleFormula(n=2, constant=-1),
            reaction_depth=SimpleFormula(n=2, constant=-1),
            workspace=SimpleFormula(constant=1),
        ),
        Adder(
            author="Gidney",
            year=2017,
            citation="gidney2018halving",
            type="Ripple Carry",
            in_place=False,
            toffolis=SimpleFormula(n=1, constant=-1),
            reaction_depth=SimpleFormula(n=1, constant=-1),
            workspace=SimpleFormula(constant=1),
        ),
        Adder(
            author="Gidney",
            year=2017,
            citation="gidney2018halving",
            type="Ripple Carry",
            in_place=True,
            toffolis=SimpleFormula(n=1, constant=-1),
            reaction_depth=SimpleFormula(n=2, constant=-1),
            workspace=SimpleFormula(n=1),
            toffoli_usage=hold(duration=SimpleFormula(n=1, constant=-1)).then(
                hold(duration=SimpleFormula(n=1), height=0)),
        ),
        Adder(
            author="Gossett",
            year=1998,
            citation="gossett1998carrysave",
            type="Pipelined (n summands)",
            in_place=False,
            toffolis=SimpleFormula(n=4),
            reaction_depth=SimpleFormula(constant=2),
            workspace=SimpleFormula(n2=1, n=-2),
        ),
        Adder(
            author="Draper et al.",
            year=2004,
            citation="draper2004lookaheadadder",
            type="Carry Lookahead",
            in_place=False,
            workspace=SimpleFormula(n=1, lg_n=-1),
            reaction_depth=SimpleFormula(lg_n=2, constant=6 - 3),
            toffolis=SimpleFormula(n=5, lg_n=-3, constant=-4),
            toffoli_usage=draper_lookahead_usage,
        ),
        Adder(
            author="Draper et al.",
            year=2004,
            citation="draper2004lookaheadadder",
            type="Carry Lookahead",
            in_place=True,
            workspace=SimpleFormula(n=2, lg_n=-1, constant=-1),
            reaction_depth=SimpleFormula(lg_n=4, constant=14 - 7),
            toffolis=SimpleFormula(n=10, lg_n=-6, constant=-13),
            toffoli_usage=draper_lookahead_usage.then(draper_lookahead_usage.reversed()),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Blocksize=b",
            in_place=False,
            toffolis=SimpleFormula(n=3, b=-2, n_over_b=5, O_1=True),
            reaction_depth=SimpleFormula(b=3, lg_n_over_b=4, O_1=True),
            workspace=SimpleFormula(n=2, n_over_b=5, O_1=True),
            toffoli_usage=our_block_usage
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Blocksize=b",
            in_place=True,
            toffolis=SimpleFormula(n=5, b=-4, n_over_b=10, O_1=True),
            reaction_depth=SimpleFormula(b=6, lg_n_over_b=8, O_1=True),
            workspace=SimpleFormula(n=2, n_over_b=5, O_1=True),
            toffoli_usage=our_block_usage.then(our_block_usage_uncompute),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Blocksize=$n/2$",
            in_place=False,
            toffolis=SimpleFormula(n=2),
            reaction_depth=SimpleFormula(n=1, O_1=True),
            workspace=SimpleFormula(n=1),
            toffoli_usage=two_block_usage,
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Blocksize=$n/2$",
            in_place=True,
            toffolis=SimpleFormula(n=3),
            reaction_depth=SimpleFormula(n=1.5, O_1=True),
            workspace=SimpleFormula(n=1),
            toffoli_usage=two_block_usage.then(two_block_usage_uncompute),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Carry Lookahead",
            in_place=True,
            toffolis=SimpleFormula(n=7),
            reaction_depth=SimpleFormula(lg_n=4, O_1=True),
            workspace=SimpleFormula(n=4, O_1=True),
            toffoli_usage=our_lookahead_usage.then(our_lookahead_usage_uncompute),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Carry Lookahead",
            in_place=False,
            toffolis=SimpleFormula(n=4),
            reaction_depth=SimpleFormula(lg_n=2, O_1=True),
            workspace=SimpleFormula(n=3, O_1=True),
            toffoli_usage=our_lookahead_usage,
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Blocksize=$\sqrt{n}$",
            in_place=True,
            toffolis=SimpleFormula(n=5, sqrt_n=6, O_1=True),
            reaction_depth=SimpleFormula(sqrt_n=6, lg_n=4, O_1=True),
            workspace=SimpleFormula(n=2, sqrt_n=5, O_1=True),
            toffoli_usage=our_sqrt_usage.then(our_sqrt_usage_uncompute),
        ),
        Adder(
            author="(this paper)",
            year=2020,
            citation=None,
            type="Blocksize=$\sqrt{n}$",
            in_place=False,
            toffolis=SimpleFormula(n=3, sqrt_n=3, O_1=True),
            reaction_depth=SimpleFormula(sqrt_n=3, lg_n=2, O_1=True),
            workspace=SimpleFormula(n=2, sqrt_n=5, O_1=True),
            toffoli_usage=our_sqrt_usage,
        ),
    ])
    print(comparison_table_tex)
    with open(pathlib.Path(__file__).parent.parent / 'gen/comparison_table.tex', 'w') as f:
        print(comparison_table_tex, file=f)


if __name__ == '__main__':
    main()
