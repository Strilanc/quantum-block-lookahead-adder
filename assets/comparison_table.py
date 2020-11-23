from typing import Callable, Union, List, Optional, Tuple
import matplotlib
import matplotlib.axes
import matplotlib.figure
import matplotlib.patches
import matplotlib.pyplot as plt

import dataclasses
import math
import pathlib
import numpy as np

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

    def is_b_sensitive(self):
        return bool(self.b or self.lg_n_over_b or self.n_over_b)

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
    def __init__(self, heights: Callable[[int, int], List[float]]):
        self.heights = heights

    def simulate_supply(self, n: int, b: int, max_production_rate: float) -> Tuple[float, float, float]:
        hs = self.heights(n, b)
        supplies = []
        supply = 1000000
        time = 0
        attempts = 4
        for k in range(3 + attempts):
            start_supply = supply
            start_time = time
            for h in hs:
                debt = h
                time += 1
                supplies.append(supply)
                supply += max_production_rate
                while debt > supply:
                    # Stall.
                    debt -= supply
                    supplies.append(0)
                    time += 1
                    supply = max_production_rate
                supply -= debt

            # Initially try to find stable supply and production values.
            if k < 3:
                lowest = min(supplies + [supply])
                if lowest > 0:
                    if start_supply < supply:
                        max_production_rate -= (supply - start_supply) / (time - start_time) * 0.999
                    supply -= lowest
                supplies.clear()
                time = 0
        average_supply = np.average(supplies)
        average_time = time / attempts
        return average_supply, average_time, max_production_rate

    @staticmethod
    def sequence(*items: 'Tot') -> 'Tot':
        result = items[0]
        for item in items[1:]:
            result = result.then(item)
        return result

    def __mul__(self, other: int) -> 'Tot':
        return Tot(lambda n: [e * other for e in self.heights(n)])

    def reversed(self):
        return Tot(lambda n, b: self.heights(n, b)[::-1])

    def then(self, second: 'Tot', shift: int = 0) -> 'Tot':
        def f(n: int, b: int) -> List[float]:
            h1 = self.heights(n, b)
            h2 = second.heights(n, b)
            result = list(h1)
            for k in range(len(h2)):
                i = len(h1) + k + shift
                while len(result) <= i:
                    result.append(0)
                result[i] += h2[k]
            return result
        return Tot(f)

    def tikz_plot(self, n: int, b: int) -> str:
        return tikz_plot(self.heights(n, b))

    def overlap(self, second: 'Tot', shift: int = 0):
        def f(n: int, b: int) -> List[int]:
            h1 = self.heights(n, b)
            h2 = second.heights(n, b)
            result = list(h1)
            for k in range(len(h2)):
                i = k + shift
                while len(result) <= i:
                    result.append(0)
                result[i] += h2[k]
            return result
        return Tot(f)


def fold_down(*, scale: float = 1, skip_start: int = 0, skip_end: int = 0, width: SimpleFormula = SimpleFormula(n=1)) -> Tot:
    def f(n: int, b: int) -> List[float]:
        result = []
        k = width.value(n, b)
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
    return Tot(lambda n, b: [height.value(n, b)] * int(math.ceil(duration.value(n, b))))


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
    dominated_in_phase_diagram: bool = False

    def toffoli_usage_or_def(self, n: int, b: int) -> Tot:
        if self.toffoli_usage is None:
            t = self.reaction_depth.value(n, b)
            v = self.toffolis.value(n, b)
            return hold(duration=t, height=v / t)
        return self.toffoli_usage

    def toffoli_usage_tikz_plot(self) -> str:
        return self.toffoli_usage_or_def(DEFAULT_N, DEFAULT_B).tikz_plot(DEFAULT_N, DEFAULT_B)

    def is_b_sensitive(self):
        return (
            self.reaction_depth.is_b_sensitive() or
            self.toffolis.is_b_sensitive() or
            self.workspace.is_b_sensitive()
        )

    def vol(self,
            *,
            n: int,
            factory_count: int,
            factory_period: float = 165,
            factory_area: float = 12 * 6,
            reaction_time: float = 10) -> float:
        if self.is_b_sensitive():
            bs = range(2, n + 1)
            if len(bs) > 50:
                bs = list(range(2, 50))
                while bs[-1] < n / 2:
                    bs.append(int(bs[-1] * 1.2))
        else:
            bs = [DEFAULT_B]
        return min(self.vol_b(
            n=n,
            b=b,
            factory_count=factory_count,
            factory_period=factory_period,
            factory_area=factory_area,
            reaction_time=reaction_time)
            for b in bs
        )

    def vol_b(self,
            *,
            n: int,
            b: int,
            factory_count: int,
            factory_period: int = 165,
            factory_area: int = 12 * 6,
            reaction_time: int = 10) -> float:
        tof = self.toffolis.value(n, b)
        dep = self.reaction_depth.value(n, b)
        space = self.workspace.value(n, b)
        average_supply, average_time, max_production_rate = self.toffoli_usage_or_def(n, b).simulate_supply(
            n, b, max_production_rate=factory_count / factory_period * reaction_time)
        space += average_supply
        if self.in_place:
            space += 2*n
        else:
            space += 3*n
        time = average_time * reaction_time
        result = factory_area * factory_period * tof + space * time
        result /= 1000 * 1000  # Microseconds to seconds.
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
                v = str(int(adder.vol(n=n, factory_count=f)))
                if len(v) > 2:
                    v = v[:2] + '0' * (len(v) - 2)
                diagram.write(vol_col + c, row + r, '&' + v)
            diagram.write(last_col, row + r, '\\\\')
    contents = diagram.render(horizontal_spacing=1, vertical_spacing=0)
    return r"\begin{tabular}{r|c|c|l|l|l|l" + '|c' * len(params) + "}\n" + contents + "\n\end{tabular}"


def plot_phase_diagram(adders: List[Adder], out_dir: pathlib.Path):
    adders = sorted(adders, key=lambda adder: (adder.year, adder.author))
    adders = [adder for adder in adders if not adder.dominated_in_phase_diagram]
    in_place_adders = [adder for adder in adders if adder.in_place]
    out_of_place_adders = [adder for adder in adders if not adder.in_place]

    register_sizes = [8]
    g = 1.5
    max_n = 20000
    max_f = max_n
    while register_sizes[-1] < max_n:
        register_sizes.append(int(math.ceil(register_sizes[-1] * g)))
    register_sizes[-1] = max_n
    factory_counts = [8]
    while factory_counts[-1] < max_f:
        factory_counts.append(int(math.ceil(factory_counts[-1] * g)))
    factory_counts[-1] = max_f
    plot_phase_diagram_helper(out_of_place_adders,
                              "Min-volume out-of-place adder vs size and factories",
                              filepath=out_dir / 'out-of-place-min-vol.pdf',
                              d=1.0,
                              factory_counts=factory_counts,
                              register_sizes=register_sizes)
    plot_phase_diagram_helper(in_place_adders,
                              "Min-volume in-place adder vs size and factories",
                              filepath=out_dir / 'in-place-min-vol.pdf',
                              d=1.0,
                              factory_counts=factory_counts,
                              register_sizes=register_sizes)
    plot_phase_diagram_helper(out_of_place_adders,
                              "Min-volume out-of-place adder vs size and half-distance factories",
                              filepath=out_dir / 'out-of-place-min-vol-half.pdf',
                              d=0.5,
                              factory_counts=factory_counts,
                              register_sizes=register_sizes)
    plot_phase_diagram_helper(in_place_adders,
                              "Min-volume out-of-place adder vs size and half-distance factories",
                              filepath=out_dir / 'in-place-min-vol-half.pdf',
                              d=0.5,
                              factory_counts=factory_counts,
                              register_sizes=register_sizes)


def plot_phase_diagram_helper(adder_set: List[Adder],
                              title: str,
                              filepath: pathlib.Path,
                              d: float,
                              factory_counts: List[int],
                              register_sizes: List[int]):
    data = np.zeros(shape=(len(factory_counts), len(register_sizes)), dtype=np.int32)
    fig: matplotlib.figure.Figure = plt.figure()
    colors = plt.get_cmap('tab10')
    ax: matplotlib.axes.Axes = fig.add_subplot(1, 1, 1)
    print("#" * len(register_sizes))
    for i, n in enumerate(register_sizes):
        print(".", end='')
        for j, f in enumerate(factory_counts):
            data[j, i] = min(range(len(adder_set)),
                             key=lambda k: adder_set[k].vol(n=n, factory_count=f,
                                                            factory_area=12 * 6 * d**2,
                                                            factory_period= 165 * d))
    print()
    data = data[::-1, :]
    ax.imshow(data, cmap=colors, vmin=0, vmax=len(colors.colors))
    ax.set_title(title)
    fig.set_size_inches(12, 5)
    ax.set_ylabel(r'Maximum factory count (f)')
    ax.set_xlabel(r'Register size (n)')
    yt = [10**k for k in range(20) if factory_counts[0] < 10**k < factory_counts[-1]]
    xt = [10**k for k in range(20) if register_sizes[0] < 10**k < register_sizes[-1]]

    def logifx(x):
        return (
                (math.log(x) - math.log(register_sizes[0]))
                / (math.log(register_sizes[-1]) - math.log(register_sizes[0]))
                * data.shape[1]
        )

    def logify(y):
        return (
            data.shape[0] - 1 -
                (math.log(y) - math.log(factory_counts[0]))
                / (math.log(factory_counts[-1]) - math.log(factory_counts[0]))
                * data.shape[0]
        )

    ax.set_xticks([logifx(x) for x in xt])
    ax.set_yticks([logify(y) for y in yt])
    ax.set_xticklabels([str(x) for x in xt])
    ax.set_yticklabels([str(y) for y in yt])

    ax.legend(
        handles=[
            matplotlib.patches.Patch(
                color=color,
                label=f"{adder.author} ({adder.year}) {adder.type}".replace('=b', '=best'))
            for adder, color in zip(adder_set, colors.colors)
        ],
        bbox_to_anchor=(1.95, 1),
        loc='upper right')

    plt.savefig(filepath)
    print(f"Generated file://{filepath}")


def plot_volume_vs_size(adders: List[Adder], out_dir: pathlib.Path):
    adders = sorted(adders, key=lambda adder: (adder.reaction_depth.value(1000000, b=20) + adder.year*20, adder.year, adder.author))
    in_place_adders = [adder for adder in adders if adder.in_place]
    out_of_place_adders = [adder for adder in adders if not adder.in_place]

    ns = [32]
    max_n = 100000
    while ns[-1] < max_n:
        ns.append(int(ns[-1] * 2))
    ns[-1] = max_n
    for name, adder_set in [('Out-of-place', out_of_place_adders), ('In-place', in_place_adders)]:
        curves = []
        for adder in adder_set:
            volumes = []
            for n in ns:
                volumes.append(adder.vol(n=n, factory_count=int(math.ceil(n*0.1))))
            curves.append((adder, volumes))
        fig: matplotlib.figure.Figure = plt.figure()
        ax: matplotlib.axes.Axes = fig.add_subplot(1, 1, 1)
        for c in curves:
            ax.plot(ns, c[1])
        ax.set_title(f'{name} adder volume vs register size (n) using n/10 factories')
        ax.set_ylabel(r'Estimated volume (logical qubit $\cdot$ seconds)')
        ax.set_xlabel(r'Register size')
        ax.set_yscale('log')
        ax.set_xscale('log')
        ax.legend([f"{adder.author} ({adder.year}) {adder.type}".replace('=b', '=best')
                    for adder in adder_set])
        path = str(out_dir / f'{name.lower()}-size-vs-vol.pdf')
        fig.savefig(path)
        print(f"Generated file://{path}")


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
        fold_down(scale=2, skip_start=1, width=SimpleFormula(b=1)),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1, width=SimpleFormula(b=1)).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=0, skip_start=1, width=SimpleFormula(b=1)).reversed(),
            shift=1
        ),
    )
    our_lookahead_usage_block_spread_uncompute = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=0, skip_start=1, width=SimpleFormula(b=1)),
        # Spread zero-rooted ranges. (0 cost when uncomputing)
        fold_down(scale=0, skip_start=1, width=SimpleFormula(b=1)).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=2, skip_start=1, width=SimpleFormula(b=1)).reversed(),
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
        fold_down(scale=2, skip_start=1, width=SimpleFormula(sqrt_n=1)),
        # Spread zero-rooted ranges.
        fold_down(skip_start=1, width=SimpleFormula(sqrt_n=1)).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=0, skip_start=1, width=SimpleFormula(sqrt_n=1)).reversed(),
            shift=1
        ),
    )
    our_lookahead_usage_sqrt_spread_uncompute = Tot.sequence(
        # Grow centered ranges.
        fold_down(scale=0, skip_start=1, width=SimpleFormula(sqrt_n=1)),
        # Spread zero-rooted ranges. (0 cost when uncomputing)
        fold_down(scale=0, skip_start=1, width=SimpleFormula(sqrt_n=1)).reversed().overlap(
            # Uncompute centered ranges.
            fold_down(scale=2, skip_start=1, width=SimpleFormula(sqrt_n=1)).reversed(),
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

    adders = [
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
            type="Carry Save (avg over n)",
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
            dominated_in_phase_diagram=True,
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
            dominated_in_phase_diagram=True,
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
            dominated_in_phase_diagram=True,
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
            dominated_in_phase_diagram=True,
        ),
    ]

    out_dir = pathlib.Path(__file__).parent.parent / 'gen'
    comparison_table_tex = make_table(adders)
    print(comparison_table_tex)
    comp_path = out_dir / 'comparison_table.tex'
    with open(comp_path, 'w') as f:
        print(comparison_table_tex, file=f)
    print(f"Generated file://{comp_path}")
    plot_volume_vs_size(adders, out_dir)
    plot_phase_diagram(adders, out_dir)


if __name__ == '__main__':
    main()